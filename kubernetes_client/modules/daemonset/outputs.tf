output "manifest" {
  value = yamlencode({
    apiVersion = "apps/v1"
    kind       = "DaemonSet"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
    }
    spec = merge({
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