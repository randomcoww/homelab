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
      dnsPolicy         = "ClusterFirstWithHostNet"
      restartPolicy     = "Always"
    }, var.spec)
  })
}