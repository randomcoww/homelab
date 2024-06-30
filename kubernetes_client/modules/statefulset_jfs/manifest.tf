locals {
  cert_path    = "/etc/certs/client.crt"
  key_path     = "/etc/certs/client.key"
  ca_cert_path = "/etc/certs/ca.crt"
}

module "secret" {
  source  = "../secret"
  name    = "${var.name}-jfs"
  app     = var.name
  release = var.release
  data = {
    basename(local.cert_path)    = tls_locally_signed_cert.redis-client.cert_pem
    basename(local.key_path)     = tls_private_key.redis-client.private_key_pem
    basename(local.ca_cert_path) = var.redis_ca.cert_pem
  }
}

module "statefulset" {
  source            = "../statefulset"
  name              = var.name
  app               = var.app
  release           = var.release
  replicas          = 1
  affinity          = var.affinity
  min_ready_seconds = var.min_ready_seconds
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
  tolerations            = var.tolerations
  volume_claim_templates = var.volume_claim_templates
  spec = merge(var.spec, {
    minReadySeconds = var.min_ready_seconds
    initContainers = concat([
      {
        name  = "${var.name}-jfs-format"
        image = var.jfs_image
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          exec juicefs format \
            'rediss://${var.redis_endpoint}/${var.redis_db_id}?tls-cert-file=${local.cert_path}&tls-key-file=${local.key_path}&tls-ca-cert-file=${local.ca_cert_path}' \
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
        volumeMounts = [
          {
            name      = "jfs-redis-tls"
            mountPath = local.cert_path
            subPath   = basename(local.cert_path)
          },
          {
            name      = "jfs-redis-tls"
            mountPath = local.key_path
            subPath   = basename(local.key_path)
          },
          {
            name      = "jfs-redis-tls"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
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
          mkdir -p ${var.jfs_mount_path}

          exec juicefs mount \
            'rediss://${var.redis_endpoint}/${var.redis_db_id}?tls-cert-file=${local.cert_path}&tls-key-file=${local.key_path}&tls-ca-cert-file=${local.ca_cert_path}' \
            ${var.jfs_mount_path} \
            --storage minio \
            --bucket ${var.jfs_minio_resource} \
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
          {
            name      = "jfs-redis-tls"
            mountPath = local.cert_path
            subPath   = basename(local.cert_path)
          },
          {
            name      = "jfs-redis-tls"
            mountPath = local.key_path
            subPath   = basename(local.key_path)
          },
          {
            name      = "jfs-redis-tls"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
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
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "jfs-mount"
            mountPath = dirname(var.jfs_mount_path)
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
      {
        name = "jfs-redis-tls"
        secret = {
          secretName = module.secret.name
        }
      }
    ])
  })
}
