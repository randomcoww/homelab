output "manifests" {
  value = concat([
    module.service.manifest,
    module.secret.manifest,
    module.httproute.manifest,
    module.deployment.manifest,
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