output "manifest" {
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Pod"
    metadata = {
      name        = var.name
      namespace   = var.namespace
      annotations = var.annotations
      labels = {
        k8s-app = var.name
      }
    }
    spec = merge({
      priority          = 2000001000
      priorityClassName = "system-node-critical"
      hostUsers         = true
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