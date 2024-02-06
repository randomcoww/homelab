output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Pod"
    metadata = {
      name      = var.name
      namespace = var.namespace
      labels = {
        app = var.name
      }
    }
    spec = merge({
      priorityClassName = "system-node-critical"
      priority          = 2000001000
      hostNetwork       = true
      restartPolicy     = "Always"
      dnsConfig = {
        options = [
          {
            name  = "ndots"
            value = "2"
          },
        ]
      }
    }, var.spec)
  })
}