output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.minio-user-secret.manifest,
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
  ], module.litestream-overlay.additional_manifests)
}