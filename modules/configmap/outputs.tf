output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
    }
    data = {
      for k, values in var.data :
      k => try(join("\n", values), values)
    }
  })
}

output "name" {
  value = var.name
}