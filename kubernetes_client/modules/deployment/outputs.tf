output "manifest" {
  value = yamlencode({
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
    }
    spec = merge({
      replicas = var.replicas
      strategy = merge({
        type = "RollingUpdate"
      }, var.strategy)
      selector = {
        matchLabels = {
          app = var.app
        }
      }
      template = {
        metadata = {
          labels = {
            app = var.app
          }
          annotations = var.annotations
        }
        spec = merge({
          affinity = merge({
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