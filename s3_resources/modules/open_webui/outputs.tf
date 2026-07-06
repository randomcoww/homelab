output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.minio-user-secret.manifest,
    ], [
    for _, m in [
      # database
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          instances = 3
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = "open-webui"
              owner    = "open-webui"
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}