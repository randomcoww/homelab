module "statefulset" {
  source = "../statefulset_litestream"
  ## litestream settings
  litestream_image  = var.litestream_image
  litestream_config = var.litestream_config
  sqlite_path       = var.sqlite_path
  ##

  name                   = var.name
  app                    = var.app
  release                = var.release
  affinity               = var.affinity
  annotations            = var.annotations
  tolerations            = var.tolerations
  volume_claim_templates = var.volume_claim_templates
  spec = merge(var.spec, {
    minReadySeconds = var.min_ready_seconds
    initContainers = concat([
      {
        name  = "${var.name}-jfs-format"
        image = var.jfs_image
        # Add --enable-acl=true in 1.2+
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          exec juicefs format \
            sqlite3://${var.sqlite_path} \
            ${var.name} \
            --storage minio \
            --bucket ${var.jfs_minio_resource} \
            --trash-days 0
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
    ], lookup(var.spec, "initContainers", []))
    containers = concat([
      {
        name  = "${var.name}-jfs-mount"
        image = var.jfs_image
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          mkdir -p \
            ${var.jfs_mount_path}

          exec juicefs mount \
            sqlite3://${var.sqlite_path} \
            ${var.jfs_mount_path} \
            --storage minio \
            --bucket ${var.jfs_minio_resource} \
            --no-syslog \
            --atime-mode noatime \
            --backup-meta 0 \
            --enable-xattr \
            --enable-ioctl \
            -o allow_other,writeback_cache,noatime
          EOF
        ]
        volumeMounts = [
          {
            name             = "jfs-mount"
            mountPath        = dirname(var.jfs_mount_path)
            mountPropagation = "Bidirectional"
          },
        ]
        resources = {
          limits = {
            "github.com/fuse" = 1
          }
        },
        securityContext = {
          privileged = true
        }
      },
      ], [
      for _, container in lookup(var.spec, "containers", []) :
      merge(container, {
        securityContext = merge(lookup(container, "securityContext", {}), {
          # required for bidirectional mount
          privileged = true
        })
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name             = "jfs-mount"
            mountPath        = dirname(var.jfs_mount_path)
            mountPropagation = "Bidirectional"
          },
        ])
      })
    ])
    volumes = concat(lookup(var.spec, "volumes", []), [
      {
        name = "jfs-mount"
        emptyDir = {
          medium = "Memory"
        }
      },
    ])
  })
}
