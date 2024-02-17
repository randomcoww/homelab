output "manifest" {
  value = yamlencode({
    apiVersion = "apps/v1"
    kind       = "StatefulSet"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
    }
    spec = {
      serviceName = var.app
      replicas    = var.replicas
      updateStrategy = {
        type = "RollingUpdate"
      }
      minReadySeconds = var.min_ready_seconds
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
        }, var.spec)
      }
      volumeClaimTemplates = var.volume_claim_templates
    }
  })
}

output "name" {
  value = var.name
}