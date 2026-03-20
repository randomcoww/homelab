module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "cni-conf.json" = jsonencode({
      name       = "cbr0"
      cniVersion = var.cni_version
      plugins = [
        {
          type = "flannel"
          delegate = {
            type             = "bridge"
            hairpinMode      = true
            isDefaultGateway = true
            bridge           = var.cni_bridge_interface_name
          }
        },
        {
          type = "portmap"
          capabilities = {
            portMappings = true
          }
        },
      ]
    })
    "net-conf.json" = jsonencode({
      Network = var.kubernetes_pod_prefix
      Backend = {
        Type = "host-gw"
      }
      EnableNFTables = true
    })
  }
}

module "daemonset" {
  source  = "../../../modules/daemonset"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  template_spec = {
    priorityClassName  = "system-node-critical"
    hostNetwork        = true
    serviceAccountName = var.name
    tolerations = [
      {
        operator = "Exists"
        effect   = "NoExecute"
      },
      {
        operator = "Exists"
        effect   = "NoSchedule"
      },
    ]
    resources = {
      requests = {
        memory = "64Mi"
      }
      limits = {
        memory = "64Mi"
      }
    }
    initContainers = [
      {
        name  = "${var.name}-cni-plugin"
        image = var.images.flannel_cni_plugin
        command = [
          "cp",
        ]
        args = [
          "-f",
          "/flannel",
          var.cni_bin_path,
        ]
        volumeMounts = [
          {
            name      = "cni-plugin"
            mountPath = var.cni_bin_path
          },
        ]
      },
      {
        name  = "${var.name}-install-cni"
        image = var.images.flannel
        command = [
          "cp",
        ]
        args = [
          "-f",
          "/etc/kube-flannel/cni-conf.json",
          "${var.cni_config_path}/10-flannel.conflist",
        ]
        volumeMounts = [
          {
            name      = "cni"
            mountPath = var.cni_config_path
          },
          {
            name      = "flannel-cfg"
            mountPath = "/etc/kube-flannel"
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.flannel
        command = [
          "/opt/bin/flanneld",
        ]
        args = [
          "--ip-masq",
          "--kube-subnet-mgr",
          "--iface=$(POD_IP)",
          "--public-ip=$(POD_IP)",
          "--healthz-ip=127.0.0.1",
          "--healthz-port=${var.ports.healthz}",
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_ADMIN",
              "NET_RAW",
            ]
          }
        }
        env = [
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
          {
            name = "POD_NAMESPACE"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.namespace"
              }
            }
          },
          {
            name = "POD_IP"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
          {
            name  = "EVENT_QUEUE_DEPTH"
            value = "5000"
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.healthz
            path   = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.healthz
            path   = "/healthz"
          }
        }
        volumeMounts = [
          {
            name      = "run"
            mountPath = "/run/flannel"
          },
          {
            name      = "flannel-cfg"
            mountPath = "/etc/kube-flannel"
          },
          {
            name      = "service-account"
            mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
            readOnly  = true
          },
        ]
      },
    ]
    volumes = [
      {
        name = "cni-plugin"
        hostPath = {
          path = var.cni_bin_path
        }
      },
      {
        name = "run"
        hostPath = {
          path = "/run/flannel"
        }
      },
      {
        name = "cni"
        hostPath = {
          path = var.cni_config_path
        }
      },
      {
        name = "flannel-cfg"
        configMap = {
          name = module.configmap.name
        }
      },
      {
        name = "service-account"
        projected = {
          sources = [
            {
              serviceAccountToken = {
                path              = "token"
                expirationSeconds = 3600
              }
            },
            {
              downwardAPI = {
                items = [
                  {
                    path = "namespace"
                    fieldRef = {
                      fieldPath = "metadata.namespace"
                    }
                  },
                ]
              }
            },
            {
              configMap = {
                name = "kube-root-ca.crt"
                items = [
                  {
                    key  = "ca.crt"
                    path = "ca.crt"
                  },
                ]
              }
            },
          ]
        }
      },
    ]
  }
}