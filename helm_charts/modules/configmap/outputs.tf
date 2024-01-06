output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        chart   = var.name
        release = "${var.name}-${var.release}"
      }
      annotations = var.annotations
    }
    data = {
      for k, values in var.data :
      k => join("\n", values)
    }
  })
}