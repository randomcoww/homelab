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
      priority          = 2000000000
      priorityClassName = "system-cluster-critical"
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
  sensitive = true
}