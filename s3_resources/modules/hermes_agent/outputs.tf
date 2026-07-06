output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.secret.manifest,
    module.juicefs-secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.minio-user-secret.manifest,
    module.mcp-client-tls.manifest,
    ], [
    for _, m in [
      # data volume
      {
        apiVersion = "v1"
        kind       = "PersistentVolume"
        metadata = {
          name = "${var.name}-${var.minio_bucket}"
        }
        spec = {
          capacity = {
            storage = "16Gi"
          }
          volumeMode = "Filesystem"
          accessModes = [
            "ReadWriteOnce",
          ]
          storageClassName = ""
          claimRef = {
            namespace = var.namespace
            name      = "${var.name}-${var.minio_bucket}"
          }
          csi = {
            driver       = "csi.juicefs.com"
            volumeHandle = "${var.name}-${var.minio_bucket}"
            fsType       = "juicefs"
            nodePublishSecretRef = {
              name      = module.juicefs-secret.name
              namespace = var.namespace
            }
          }
        }
      },
      {
        apiVersion = "v1"
        kind       = "PersistentVolumeClaim"
        metadata = {
          name      = "${var.name}-${var.minio_bucket}"
          namespace = var.namespace
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          volumeMode       = "Filesystem"
          storageClassName = ""
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
          volumeName = "${var.name}-${var.minio_bucket}"
        }
      },
      # data volume metadata
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
              database = local.juicefs_postgres_database
              owner    = local.juicefs_postgres_user
              secret = {
                name = module.juicefs-secret.name
              }
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ], module.litestream-overlay.additional_manifests)
}