output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name = var.name
      labels = {
        app     = var.name
        chart   = var.name
        release = "${var.name}-${var.release}"
      }
      annotations = var.annotations
    }
    spec = merge({
      selector = {
        matchLabels = {
          app     = var.name
          release = "${var.name}-${var.release}"
        }
      }
    }, var.spec)
  })
}