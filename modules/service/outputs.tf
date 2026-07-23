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
      selector = merge({
        app = var.app
      }, var.selector)
    }, var.spec)
  })
}

output "name" {
  value = var.name
}