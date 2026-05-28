output "manifest" {
  value = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
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
    spec = var.spec
  })
}

output "name" {
  value = var.name
}