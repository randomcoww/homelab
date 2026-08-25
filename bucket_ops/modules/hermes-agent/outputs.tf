output "manifests" {
  value = concat([
    module.statefulset.manifest,
    module.secret.manifest,
    module.env-secret.manifest,
    module.juicefs-secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
    module.minio-user-secret.manifest,
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
          labels = {
            app       = var.name
            namespace = var.namespace
          }
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

      # juicefs data volume metadata
      {
        apiVersion = "cert-manager.io/v1"
        kind       = "Certificate"
        metadata = {
          name      = "${local.juicefs_name}-pg-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${local.juicefs_name}-pg-tls"
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
            "${local.juicefs_name}-pg-rw",
            "${local.juicefs_name}-pg-rw.${var.namespace}",
            "${local.juicefs_name}-pg-r",
            "${local.juicefs_name}-pg-r.${var.namespace}",
            "${local.juicefs_name}-pg-ro",
            "${local.juicefs_name}-pg-ro.${var.namespace}",
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
          name      = "${local.juicefs_name}-pg-rep-client-tls"
          namespace = var.namespace
        }
        spec = {
          secretName = "${local.juicefs_name}-pg-rep-client-tls"
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
          name      = "${local.juicefs_name}-pg"
          namespace = var.namespace
          labels = {
            "cnpg.io/reload" = "true"
          }
        }
        spec = {
          instances = 2
          certificates = {
            serverTLSSecret      = "${local.juicefs_name}-pg-tls"
            serverCASecret       = "${local.juicefs_name}-pg-tls"
            clientCASecret       = "${local.juicefs_name}-pg-rep-client-tls"
            replicationTLSSecret = "${local.juicefs_name}-pg-rep-client-tls"
          }
          storage = {
            size = "2Gi"
          }
          bootstrap = {
            initdb = {
              database = local.juicefs_postgres_database
              owner    = local.juicefs_postgres_username
              secret = {
                name = module.juicefs-secret.name
              }
            }
          }
          resources = {
            requests = {
              memory = "256Mi"
            }
            limits = {
              memory = "512Mi"
            }
          }
        }
      },
      {
        apiVersion = "monitoring.coreos.com/v1"
        kind       = "PodMonitor"
        metadata = {
          name      = "${local.juicefs_name}-pg"
          namespace = var.namespace
        }
        spec = {
          selector = {
            matchLabels = {
              "cnpg.io/cluster" = "${local.juicefs_name}-pg"
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

output "juicefs-mountopts" {
  value = {
    pvcSelector = {
      matchLabels = {
        app       = var.name
        namespace = var.namespace
      }
    }
    resources = {
      requests = {
        memory = "2Gi"
      }
    }
  }
}