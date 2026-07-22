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
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "ServiceMonitor"
        metadata = {
          name      = var.name
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              app = var.name
            }
          }
          endpoints = [
            {
              path       = local.extra_envs.ND_PROMETHEUS_METRICSPATH
              targetPort = local.extra_envs.ND_PORT
            },
          ]
        }
      },
    ] :
    yamlencode(m)
  ], module.litestream-overlay.additional_manifests)
}