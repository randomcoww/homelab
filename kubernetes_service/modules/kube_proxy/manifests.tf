module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/serviceaccount.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "ServiceAccount"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
    })
    "templates/clusterrolebinding.yaml" = yamlencode({
      apiVersion = "rbac.authorization.k8s.io/v1"
      kind       = "ClusterRoleBinding"
      metadata = {
        name = "system:kube-proxy"
        labels = {
          app     = var.name
          release = var.release
        }
      }
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "ClusterRole"
        name     = "system:node-proxier"
      }
      subjects = [
        {
          kind      = "ServiceAccount"
          name      = var.name
          namespace = var.namespace
        },
      ]
    })
    "templates/daemonset.yaml" = module.daemonset.manifest
  }
}

module "daemonset" {
  source   = "../../../modules/daemonset"
  name     = var.name
  app      = var.name
  affinity = var.affinity
  release  = var.release
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.kube_proxy_metrics)
  }
  template_spec = {
    automountServiceAccountToken = true
    priorityClassName            = "system-node-critical"
    hostNetwork                  = true
    serviceAccountName           = var.name
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
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.kube_proxy
        command = [
          "kube-proxy",
          "--hostname-override=$(NODE_NAME)",
          "--cluster-cidr=${var.kubernetes_pod_prefix}",
          "--proxy-mode=nftables",
          "--v=2",
          "--init-only",
        ]
        env = [
          {
            name = "NODE_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "spec.nodeName"
              }
            }
          },
          {
            name  = "KUBERNETES_SERVICE_HOST"
            value = var.kube_apiserver_ip
          },
          {
            name  = "KUBERNETES_SERVICE_PORT"
            value = tostring(var.ports.kube_apiserver)
          },
        ]
        securityContext = {
          privileged = true
        }
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.kube_proxy
        command = [
          "kube-proxy",
          "--hostname-override=$(NODE_NAME)",
          "--cluster-cidr=${var.kubernetes_pod_prefix}",
          "--proxy-mode=nftables",
          "--healthz-bind-address=127.0.0.1:${var.ports.kube_proxy}",
          "--metrics-bind-address=$(POD_IP):${var.ports.kube_proxy_metrics}",
          "--v=2",
        ]
        env = [
          {
            name = "NODE_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "spec.nodeName"
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
            name  = "KUBERNETES_SERVICE_HOST"
            value = var.kube_apiserver_ip
          },
          {
            name  = "KUBERNETES_SERVICE_PORT"
            value = tostring(var.ports.kube_apiserver)
          },
        ]
        securityContext = {
          capabilities = {
            add = [
              "NET_ADMIN",
            ]
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.kube_proxy
            path   = "/livez"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.kube_proxy
            path   = "/healthz"
          }
        }
      },
    ]
  }
}