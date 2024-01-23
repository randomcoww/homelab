output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
    }
    stringData = {
      for k, values in var.data :
      k => try(join("\n", values), values)
    }
  })
}