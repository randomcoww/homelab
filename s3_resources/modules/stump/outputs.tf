output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.secret.manifest,
    module.juicefs-secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.minio-user-secret.manifest,
    ], [
    for _, m in [
      # data bucket
      {
        apiVersion = "v1"
        kind       = "PersistentVolume"
        metadata = {
          name = "${var.name}-${var.minio_data_bucket}"
        }
        spec = {
          capacity = {
            storage = "16Gi"
          }
          accessModes = [
            "ReadOnlyMany",
          ]
          storageClassName = ""
          claimRef = {
            namespace = var.namespace
            name      = "${var.name}-${var.minio_data_bucket}"
          }
          mountOptions = [
            "endpoint-url ${var.minio_endpoint}",
            "force-path-style",
            "maximum-throughput-gbps 1",
            "metadata-ttl 300",
          ]
          csi = {
            driver       = "s3.csi.aws.com"
            volumeHandle = "${var.name}-${var.minio_data_bucket}"
            volumeAttributes = {
              authenticationSource                       = "driver"
              bucketName                                 = var.minio_data_bucket
              cache                                      = "emptyDir"
              cacheEmptyDirSizeLimit                     = "1Gi"
              cacheEmptyDirMedium                        = "Memory"
              mountpointContainerResourcesRequestsMemory = "1Gi"
            }
          }
        }
      },
      {
        apiVersion = "v1"
        kind       = "PersistentVolumeClaim"
        metadata = {
          name      = "${var.name}-${var.minio_data_bucket}"
          namespace = var.namespace
        }
        spec = {
          accessModes = [
            "ReadOnlyMany",
          ]
          storageClassName = ""
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
          volumeName = "${var.name}-${var.minio_data_bucket}"
        }
      },

      # cache volume
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
          labels = {
            "cnpg.io/reload" = "true"
          }
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
          resources = {
            requests = {
              memory = "256Mi"
            }
          }
        }
      },
    ] :
    yamlencode(m)
  ], module.litestream-overlay.additional_manifests)
}