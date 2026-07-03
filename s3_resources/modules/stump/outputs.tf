output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.secret.manifest,
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
            "maximum-throughput-gbps 1",
          ]
          csi = {
            driver       = "s3.csi.aws.com"
            volumeHandle = "${var.name}-${var.minio_data_bucket}"
            volumeAttributes = {
              authenticationSource   = "driver"
              bucketName             = var.minio_data_bucket
              cache                  = "emptyDir"
              cacheEmptyDirSizeLimit = "1Gi"
              cacheEmptyDirMedium    = "Memory"
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

      # thumbnails bucket
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
          accessModes = [
            "ReadWriteMany",
          ]
          storageClassName = ""
          claimRef = {
            namespace = var.namespace
            name      = "${var.name}-${var.minio_bucket}"
          }
          mountOptions = [
            "endpoint-url ${var.minio_endpoint}",
            "maximum-throughput-gbps 1",
            "prefix thumbnails/",
            "allow-overwrite",
            "allow-delete",
          ]
          csi = {
            driver       = "s3.csi.aws.com"
            volumeHandle = "${var.name}-${var.minio_bucket}"
            volumeAttributes = {
              authenticationSource   = "driver"
              bucketName             = var.minio_bucket
              cache                  = "emptyDir"
              cacheEmptyDirSizeLimit = "1Gi"
              cacheEmptyDirMedium    = "Memory"
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
            "ReadWriteMany",
          ]
          storageClassName = ""
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
          volumeName = "${var.name}-${var.minio_bucket}"
        }
      },
    ] :
    yamlencode(m)
  ], module.litestream-overlay.additional_manifests)
}