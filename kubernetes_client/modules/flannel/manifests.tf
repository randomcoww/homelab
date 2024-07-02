locals {
  serviceaccount = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
    }
  }

  role = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
    }
    rules = [
      {
        apiGroups = [""]
        resources = ["pods"]
        verbs     = ["get"]
      },
      {
        apiGroups = [""]
        resources = ["nodes"]
        verbs     = ["list", "watch"]
      },
      {
        apiGroups = [""]
        resources = ["nodes/status"]
        verbs     = ["patch"]
      },
    ]
  }

  rolebinding = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        release = var.release
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = var.name
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = var.name
        namespace = var.namespace
      }
    ]
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.flannel)[1]
  manifests = {
    "templates/serviceaccount.yaml"     = yamlencode(local.serviceaccount)
    "templates/clusterrole.yaml"        = yamlencode(local.role)
    "templates/clusterrolebinding.yaml" = yamlencode(local.rolebinding)
    "templates/configmap.yaml"          = module.configmap.manifest
    "templates/daemonset.yaml"          = module.daemonset.manifest
  }
}

module "configmap" {
  source  = "../configmap"
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
        }
      ]
    })
    "net-conf.json" = jsonencode({
      Network = var.kubernetes_pod_prefix
      Backend = {
        Type = "host-gw"
      }
    })
  }
}

module "daemonset" {
  source  = "../daemonset"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "checksum/configmap" = sha256(module.configmap.manifest)
  }
  spec = {
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
          "/opt/cni/bin/flannel",
        ]
        volumeMounts = [
          {
            name      = "cni-plugin"
            mountPath = "/opt/cni/bin"
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
          "/etc/cni/net.d/10-flannel.conflist",
        ]
        volumeMounts = [
          {
            name      = "cni"
            mountPath = "/etc/cni/net.d"
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
        resources = {
          requests = {
            cpu    = "100m"
            memory = "50Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "50Mi"
          }
        }
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
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.healthz
            path   = "/healthz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.healthz
            path   = "/healthz"
          }
          initialDelaySeconds = 15
          timeoutSeconds      = 15
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
        ]
      }
    ]
    volumes = [
      {
        name = "cni-plugin"
        hostPath = {
          path = "/opt/cni/bin"
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
          path = "/etc/cni/net.d"
        }
      },
      {
        name = "flannel-cfg"
        configMap = {
          name = module.configmap.name
        }
      },
    ]
  }
}