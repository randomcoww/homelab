locals {
  db_path = "/var/lib/jfs/jfs.db"
}

module "metadata" {
  source  = "../metadata"
  name    = var.name
  release = var.release
  manifests = merge(module.litestream.chart.manifests, {
    "templates/secret-jfs.yaml" = module.secret.manifest
  })
}

module "secret" {
  source  = "../secret"
  name    = "${var.name}-jfs"
  app     = var.app
  release = var.release
  data = {
    ACCESS_KEY = var.jfs_minio_access_key_id
    SECRET_KEY = var.jfs_minio_secret_access_key
  }
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
        path = local.db_path
        replicas = [
          {
            name                     = "minio"
            type                     = "s3"
            bucket                   = var.litestream_minio_bucket
            path                     = var.litestream_minio_prefix
            endpoint                 = var.litestream_minio_endpoint
            access-key-id            = var.litestream_minio_access_key_id
            secret-access-key        = var.litestream_minio_secret_access_key
            retention                = "2m"
            retention-check-interval = "2m"
            sync-interval            = "100ms"
            snapshot-interval        = "20m"
          },
        ]
      },
    ]
  }
  sqlite_path = local.db_path
  ##
  name        = var.name
  app         = var.app
  release     = var.release
  replicas    = var.replicas
  affinity    = var.affinity
  tolerations = var.tolerations
  spec        = var.spec
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

          juicefs format \
            'sqlite3://${local.db_path}' \
            ${var.jfs_minio_prefix} \
            --storage minio \
            --bucket ${var.jfs_minio_endpoint}/${var.jfs_minio_bucket} \
            --trash-days 0

          juicefs gc \
            'sqlite3://${local.db_path}' \
            --compact \
            --delete

          juicefs fsck \
            'sqlite3://${local.db_path}'
          EOF
        ]
        env = [
          {
            name = "ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "ACCESS_KEY"
              }
            }
          },
          {
            name = "SECRET_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "SECRET_KEY"
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

          exec juicefs mount \
            'sqlite3://${local.db_path}' \
            ${var.jfs_mount_path} \
            --storage minio \
            --bucket ${var.jfs_minio_endpoint}/${var.jfs_minio_bucket} \
            --no-syslog \
            --atime-mode noatime \
            --backup-meta 0 \
            --no-usage-report true \
            -o allow_other,noatime
          EOF
        ]
        lifecycle = {
          preStop = {
            exec = {
              command = [
                "sh",
                "-c",
                <<-EOF
                set -e

                while mountpoint ${var.jfs_mount_path}; do
                juicefs umount ${var.jfs_mount_path}
                sleep 1
                done
                EOF
              ]
            }
          }
        }
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
            name      = "jfs-mount"
            mountPath = dirname(var.jfs_mount_path)
          },
        ])
      })
    ])
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "jfs-mount"
            mountPath = dirname(var.jfs_mount_path)
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
    ])
  })
}
