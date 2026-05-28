output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = merge({
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
      }, length(var.namespace) > 0 ? {
      namespace = var.namespace
    } : {})
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