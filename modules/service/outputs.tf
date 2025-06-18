output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
    }
    spec = merge({
      selector = merge({
        app = var.app
      }, var.labels)
    }, var.spec)
  })
}

output "name" {
  value = var.name
}