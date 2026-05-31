output "manifests" {
  value = concat([
    module.secret.manifest,
    module.service.manifest,
    module.web-service.manifest,
    module.httproute.manifest,
    module.statefulset.manifest,
    ], [
    for _, m in [
      {
        apiVersion = "traefik.io/v1alpha1"
        kind       = "Middleware"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          chain = {
            middlewares = [
              var.middleware_ref,
            ]
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}