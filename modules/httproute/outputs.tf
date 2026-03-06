output "manifest" {
  value = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
    }
    spec = var.spec
  })
}

output "name" {
  value = var.name
}