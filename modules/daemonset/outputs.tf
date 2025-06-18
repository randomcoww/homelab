output "manifest" {
  value = yamlencode({
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = {
        app     = var.app
        release = var.release
      }
    }
    spec = merge({
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
          affinity      = var.affinity
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