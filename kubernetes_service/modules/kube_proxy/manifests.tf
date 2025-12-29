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
    "templates/configmap.yaml" = module.configmap.manifest
    "templates/daemonset.yaml" = module.daemonset.manifest
  }
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "kube-proxy-config.yaml" = yamlencode({
      kind               = "KubeProxyConfiguration"
      apiVersion         = "kubeproxy.config.k8s.io/v1alpha1"
      mode               = "nftables"
      clusterCIDR        = var.kubernetes_pod_prefix
      healthzBindAddress = "127.0.0.1:${var.ports.kube_proxy}"
      metricsBindAddress = "0.0.0.0:${var.ports.kube_proxy_metrics}"
    })
  }
}

module "daemonset" {
  source   = "../../../modules/daemonset"
  name     = var.name
  app      = var.name
  affinity = var.affinity
  release  = var.release
  annotations = {
    "checksum/configmap"   = sha256(module.configmap.manifest)
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(var.ports.kube_proxy_metrics)
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
          "--config=/etc/kube-proxy/kube-proxy-config.yaml",
          "--hostname-override=$(NODE_NAME)",
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
        volumeMounts = [
          # /lib/modules and /run/xtables.lock mounts seem to not be needed when on nftables mode
          {
            name      = "kube-proxy-config"
            mountPath = "/etc/kube-proxy"
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.kube_proxy
        command = [
          "kube-proxy",
          "--config=/etc/kube-proxy/kube-proxy-config.yaml",
          "--hostname-override=$(NODE_NAME)",
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
        volumeMounts = [
          # /lib/modules and /run/xtables.lock mounts seem to not be needed when on nftables mode
          {
            name      = "kube-proxy-config"
            mountPath = "/etc/kube-proxy"
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            host   = "127.0.0.1"
            port   = var.ports.kube_proxy
            path   = "/livez"
          }
        }
      },
    ]
    volumes = [
      {
        name = "kube-proxy-config"
        configMap = {
          name = module.configmap.name
        }
      },
    ]
  }
}