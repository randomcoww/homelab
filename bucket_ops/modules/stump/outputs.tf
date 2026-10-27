output "manifests" {
  value = concat([
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
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
              mountpointContainerResourcesRequestsMemory = "256Mi"
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
            "force-path-style",
            "maximum-throughput-gbps 1",
            "metadata-ttl 300",
            "prefix thumbnails/",
            "allow-overwrite",
            "allow-delete",
          ]
          csi = {
            driver       = "s3.csi.aws.com"
            volumeHandle = "${var.name}-${var.minio_bucket}"
            volumeAttributes = {
              authenticationSource                       = "driver"
              bucketName                                 = var.minio_bucket
              cache                                      = "emptyDir"
              cacheEmptyDirSizeLimit                     = "1Gi"
              cacheEmptyDirMedium                        = "Memory"
              mountpointContainerResourcesRequestsMemory = "256Mi"
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

      # stump postgres
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-tls"
          secretTemplate = {
            labels = {
              "cnpg.io/reload" = ""
            }
          }
          isCA = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = var.name
          usages = [
            "server auth",
          ]
          dnsNames = [
            "${var.name}-pg-rw",
            "${var.name}-pg-rw.${var.namespace}",
            "${var.name}-pg-r",
            "${var.name}-pg-r.${var.namespace}",
            "${var.name}-pg-ro",
            "${var.name}-pg-ro.${var.namespace}",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${var.name}-pg-rep-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${var.name}-pg-rep-client-tls"
          secretTemplate = {
            labels = {
              "cnpg.io/reload" = ""
            }
          }
          isCA = false
          privateKey = {
            algorithm = "ECDSA"
            size      = 521
          }
          commonName = "streaming_replica" # required user name for replication client
          usages = [
            "client auth",
          ]
          issuerRef = {
            name = var.ca_issuer_name
            kind = "ClusterIssuer"
          }
        }
      },
      {
        apiVersion = "postgresql.cnpg.io/v1"
        kind       = "Cluster"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
          labels = {
            "cnpg.io/reload" = ""
          }
        }
        spec = {
          instances = 2
          certificates = {
            serverTLSSecret      = "${var.name}-pg-tls"
            serverCASecret       = "${var.name}-pg-tls"
            clientCASecret       = "${var.name}-pg-rep-client-tls"
            replicationTLSSecret = "${var.name}-pg-rep-client-tls"
          }
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = local.envs.STUMP_DB_NAME
              owner    = local.envs.STUMP_DB_USER
            }
          }
          resources = {
            requests = {
              memory = "256Mi"
            }
            limits = {
              memory = "256Mi"
            }
          }
        }
      },
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PodMonitor"
        metadata = {
          name      = "${var.name}-pg"
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              "cnpg.io/cluster" = "${var.name}-pg"
            }
          }
          podMetricsEndpoints = [
            {
              port = "metrics"
            },
          ]
        }
      },

      # NS
      {
        apiVersion = "v1"
        kind       = "Namespace"
        metadata = {
          name = var.namespace
          annotations = {
            "kustomize.toolkit.fluxcd.io/prune" = "disabled"
          }
        }
      },
    ] :
    yamlencode(m)
  ])
}