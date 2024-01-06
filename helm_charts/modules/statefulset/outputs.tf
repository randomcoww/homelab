output "manifest" {
  value = yamlencode({
    apiVersion = "apps/v1"
    kind       = "StatefulSet"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        chart   = var.name
        release = "${var.name}-${var.release}"
      }
    }
    spec = {
      serviceName = var.name
      replicas    = var.replicas
      updateStrategy = {
        type = "RollingUpdate"
      }
      minReadySeconds = var.min_ready_seconds
      selector = {
        matchLabels = {
          app     = var.name
          release = "${var.name}-${var.release}"
        }
      }
      template = {
        metadata = {
          labels = {
            app     = var.name
            release = "${var.name}-${var.release}"
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
                          var.name,
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
              }
            ]
          }
        }, var.spec)
      }
    }
  })
}