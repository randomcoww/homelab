output "manifest" {
  value = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name = var.name
      labels = {
        app     = var.app
        release = var.release
      }
      annotations = var.annotations
    }
    spec = merge({
      ingressClassName = var.ingress_class_name
      rules = [
        for rule in var.rules :
        {
          host = rule.host
          http = {
            paths = [
              for path in rule.paths :
              {
                path     = path.path
                pathType = "Prefix"
                backend = {
                  service = {
                    name = path.service
                    port = {
                      number = path.port
                    }
                  }
                }
              }
            ]
          }
        }
      ]
      tls = [
        for rule in distinct(var.rules) :
        {
          secretName = "${rule.host}-tls"
          hosts = [
            rule.host,
          ]
        }
      ]
    }, var.spec)
  })
}

output "name" {
  value = var.name
}