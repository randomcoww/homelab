output "manifest" {
  value = yamlencode({
    apiVersion = "apps/v1"
    kind       = "StatefulSet"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = {
        app     = var.app
        release = var.release
      }
    }
    spec = merge({
      serviceName = var.app
      replicas    = var.replicas
      updateStrategy = {
        type = "RollingUpdate"
      }
      selector = {
        matchLabels = merge({
          app = var.app
        }, var.labels)
      }
      template = {
        metadata = {
          labels = merge({
            app = var.app
          }, var.labels)
          annotations = var.annotations
        }
        spec = merge({
          automountServiceAccountToken = false
          affinity = merge({
            nodeAffinity = merge(lookup(lookup(var.template_spec, "affinity", {}), "nodeAffinity", {}), {
              preferredDuringSchedulingIgnoredDuringExecution = [
                {
                  weight = 100
                  preference = {
                    matchExpressions = [
                      {
                        key      = "beta.amd.com/gpu.cu-count"
                        operator = "Lt"
                        values = [
                          "16",
                        ]
                      },
                    ]
                  }
                },
              ]
            })
            podAntiAffinity = {
              requiredDuringSchedulingIgnoredDuringExecution = [
                {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app"
                        operator = "In"
                        values = [
                          var.app,
                        ]
                      },
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                },
              ]
            }
          }, var.affinity)
          tolerations   = var.tolerations
          restartPolicy = "Always"
          dnsConfig = {
            options = [
              {
                name  = "ndots"
                value = "2"
              },
            ]
          }
        }, var.template_spec)
      }
    }, var.spec)
  })
}

output "name" {
  value = var.name
}