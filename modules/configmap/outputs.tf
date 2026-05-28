output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
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
    data = {
      for k, values in var.data :
      k => try(join("\n", values), values)
    }
  })
}

output "name" {
  value = var.name
}