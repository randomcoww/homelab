output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = merge({
        app     = var.app
        release = var.release
      }, var.labels)
      annotations = var.annotations
    }
    spec = merge({
      selector = length(var.selector) > 0 ? var.selector : {
        app = var.app
      }
    }, var.spec)
  })
}

output "name" {
  value = var.name
}