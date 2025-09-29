
locals {
  # store both JFS write cache and litestream db here
  # https://juicefs.com/docs/community/guide/cache/#cache-dir
  jfs_cache_path = "/var/jfsCache"
  db_url         = "sqlite3://${local.jfs_cache_path}/jfs.db?_busy_timeout=5000&_synchronous=NORMAL&_wal_autocheckpoint=0"
}

module "metadata" {
  source    = "../../../modules/metadata"
  name      = var.name
  namespace = var.namespace
  release   = var.release
  manifests = module.litestream.chart.manifests
}

module "litestream" {
  source = "../statefulset_litestream"
  ## litestream settings
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path = "${local.jfs_cache_path}/jfs.db"
        replicas = [
          {
            name              = "minio"
            type              = "s3"
            endpoint          = var.minio_endpoint
            bucket            = var.minio_bucket
            path              = var.minio_litestream_prefix
            sync-interval     = "100ms"
            snapshot-interval = "1h"
            retention         = "1h"
          },
        ]
      },
    ]
  }
  sqlite_path      = "${local.jfs_cache_path}/jfs.db"
  s3_access_secret = var.minio_access_secret
  ##
  name        = var.name
  app         = var.app
  release     = var.release
  replicas    = var.replicas
  affinity    = var.affinity
  tolerations = var.tolerations
  # use local-path to keep database 
  spec = merge(var.spec, {
    volumeClaimTemplates = concat(lookup(var.spec, "volumeClaimTemplates", []), [
      {
        metadata = {
          name = "litestream-data"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "16Gi"
            }
          }
          storageClassName = "local-path"
        }
      },
    ])
  })
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      {
        name  = "${var.name}-jfs-format"
        image = var.images.jfs
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          juicefs config '${local.db_url}' \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --access-key=$ACCESS_KEY \
            --secret-key=$SECRET_KEY

          juicefs format '${local.db_url}' \
            ${var.minio_jfs_prefix} \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --trash-days=0 \
            --capacity=${var.jfs_capacity_gb}

          juicefs gc '${local.db_url}' \
            --compact \
            --delete

          juicefs fsck '${local.db_url}'
          EOF
        ]
        env = [
          {
            name = "ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "SECRET_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
        ]
      },
      {
        name          = "${var.name}-jfs-mount"
        image         = var.images.jfs
        restartPolicy = "Always"
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          mkdir -p ${var.jfs_mount_path}

          exec juicefs mount '${local.db_url}' \
            ${var.jfs_mount_path} \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --no-syslog \
            --atime-mode=noatime \
            --backup-meta=0 \
            --no-usage-report=true \
            --writeback \
            --cache-dir=${local.jfs_cache_path} \
            -o allow_other,noatime
          EOF
        ]
        volumeMounts = [
          {
            name             = "jfs-mount"
            mountPath        = dirname(var.jfs_mount_path)
            mountPropagation = "Bidirectional"
          },
        ]
        securityContext = {
          privileged = true
        }
      },
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name             = "jfs-mount"
            mountPath        = dirname(var.jfs_mount_path)
            mountPropagation = "HostToContainer"
          },
        ])
      })
    ])
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name             = "jfs-mount"
            mountPath        = dirname(var.jfs_mount_path)
            mountPropagation = "HostToContainer"
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "jfs-mount"
        emptyDir = {
          medium = "Memory"
        }
      },
      # Use local-path for this
      # {
      #   name     = "litestream-data"
      #   emptyDir = {}
      # },
    ])
  })
}
