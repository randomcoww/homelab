output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
    }
    spec = merge({
      selector = {
        app = var.app
      }
    }, var.spec)
  })
}