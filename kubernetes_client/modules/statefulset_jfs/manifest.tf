locals {
  jfs_endpoint        = join("/", slice(split("/", var.jfs_minio_bucket_endpoint), 0, length(split("/", var.jfs_minio_bucket_endpoint)) - 1))
  jfs_bucket          = reverse(split("/", var.jfs_minio_bucket_endpoint))[0]
  litestream_endpoint = join("/", slice(split("/", var.litestream_minio_bucket_endpoint), 0, length(split("/", var.litestream_minio_bucket_endpoint)) - 1))
  litestream_bucket   = reverse(split("/", var.litestream_minio_bucket_endpoint))[0]
  db_path             = "/var/lib/jfs/jfs.db"
}

module "statefulset-litestream" {
  source = "../statefulset_litestream"
  ## litestream settings
  litestream_image = var.litestream_image
  litestream_config = {
    dbs = [
      {
        path = local.db_path
        replicas = [
          {
            name                     = "minio"
            type                     = "s3"
            bucket                   = local.litestream_bucket
            path                     = var.name
            endpoint                 = local.litestream_endpoint
            access-key-id            = var.litestream_minio_access_key_id
            secret-access-key        = var.litestream_minio_secret_access_key
            retention                = "2m"
            retention-check-interval = "2m"
            sync-interval            = "500ms"
            snapshot-interval        = "1h"
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
  affinity    = var.affinity
  tolerations = var.tolerations
  spec        = var.spec
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      {
        name  = "${var.name}-jfs-format"
        image = var.jfs_image
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          juicefs format \
            'sqlite3://${local.db_path}' \
            ${var.name} \
            --storage minio \
            --bucket ${local.jfs_endpoint}/${local.jfs_bucket} \
            --trash-days 0

          juicefs fsck \
            'sqlite3://${local.db_path}'
          EOF
        ]
        env = [
          {
            name  = "ACCESS_KEY"
            value = var.jfs_minio_access_key_id
          },
          {
            name  = "SECRET_KEY"
            value = var.jfs_minio_secret_access_key
          },
        ]
      },
    ], lookup(var.template_spec, "initContainers", []))
    containers = concat([
      {
        name  = "${var.name}-jfs-mount"
        image = var.jfs_image
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
            --bucket ${local.jfs_endpoint}/${local.jfs_bucket} \
            --no-syslog \
            --atime-mode noatime \
            --backup-meta 0 \
            --no-usage-report true \
            -o allow_other,writeback_cache,noatime
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
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "jfs-mount"
            mountPath = dirname(var.jfs_mount_path)
          },
        ])
      })
    ])
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
