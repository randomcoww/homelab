module "daemonset" {
  source   = "../../../modules/daemonset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.kube_vip_metrics)
  }
  template_spec = {
    hostNetwork        = true
    priorityClassName  = "system-cluster-critical"
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
        memory = "128Mi"
      }
      limits = {
        memory = "128Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.kube_vip
        args = [
          "manager",
          "--serviceInterface=${var.service_interface}",
          "--prometheusHTTPServer=$(bgp_routerid):${var.ports.kube_vip_metrics}",
          "--cleanRoutingTable",
          "--healthCheckPort=${var.ports.kube_vip_health}",
        ]
        env = [
          {
            name  = "vip_arp"
            value = "false"
          },
          {
            name  = "port"
            value = tostring(var.ports.apiserver)
          },
          {
            name  = "vip_interface"
            value = "lo"
          },
          {
            name = "vip_nodename"
            valueFrom = {
              fieldRef = {
                fieldPath = "spec.nodeName"
              }
            }
          },
          {
            name  = "dns_mode"
            value = "first"
          },
          {
            name  = "cp_enable"
            value = "true"
          },
          {
            name  = "svc_enable"
            value = "true"
          },
          {
            name  = "lb_enable"
            value = "false"
          },
          {
            name  = "lb_port"
            value = tostring(var.ports.apiserver)
          },
          {
            name  = "svc_leasename"
            value = "plndr-svcs-lock"
          },
          {
            name  = "vip_routingtable"
            value = "false"
          },
          {
            name  = "bgp_enable"
            value = "true"
          },
          {
            name = "bgp_routerid"
            valueFrom = {
              fieldRef = {
                fieldPath = "status.podIP"
              }
            }
          },
          {
            name  = "bgp_as"
            value = tostring(var.bgp_as)
          },
          {
            name = "bgp_peers"
            value = join(",", [
              for _, ip in var.bgp_neighbor_ips :
              "${ip}:${var.bgp_peeras}::false"
            ])
          },
          {
            name  = "address"
            value = var.apiserver_ip
          },
          {
            name  = "egress_withnftables"
            value = "true"
          },
        ]
        volumeMounts = [
          {
            name      = "service-account"
            mountPath = "/var/run/secrets/kubernetes.io/serviceaccount"
            readOnly  = true
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.kube_vip_health
            path   = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.kube_vip_health
            path   = "/healthz"
          }
        }
        securityContext = {
          capabilities = {
            add = [
              "NET_ADMIN",
              "NET_RAW",
              "SYS_TIME",
            ]
          }
        }
      },
    ]
    volumes = [
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