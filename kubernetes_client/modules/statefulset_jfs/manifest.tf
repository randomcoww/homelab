locals {
  cert_path    = "/etc/certs/client.crt"
  key_path     = "/etc/certs/client.key"
  ca_cert_path = "/etc/certs/ca.crt"
  # use default postgres database as root - only one application per postgres deployment
  # metadata_url = "postgres://${var.jfs_metadata_endpoint}/postgres?sslcert=${local.cert_path}&sslkey=${local.key_path}&sslrootcert=${local.ca_cert_path}"
  metadata_url = "rediss://${var.jfs_metadata_endpoint}?tls-cert-file=${local.cert_path}&tls-key-file=${local.key_path}&tls-ca-cert-file=${local.ca_cert_path}"
  jfs_bucket   = join("/", slice(split("/", var.jfs_minio_resource), 0, length(split("/", var.jfs_minio_resource)) - 1))
  jfs_name     = reverse(split("/", var.jfs_minio_resource))[0]
}

module "secret" {
  source  = "../secret"
  name    = "${var.name}-jfs"
  app     = var.name
  release = var.release
  data = {
    basename(local.cert_path)    = tls_locally_signed_cert.metadata-client.cert_pem
    basename(local.key_path)     = tls_private_key.metadata-client.private_key_pem
    basename(local.ca_cert_path) = var.jfs_metadata_ca.cert_pem
  }
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.app
  release  = var.release
  replicas = var.replicas
  affinity = var.affinity
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
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
            '${local.metadata_url}' \
            ${local.jfs_name} \
            --storage minio \
            --bucket ${local.jfs_bucket} \
            --trash-days 0

          juicefs fsck \
            '${local.metadata_url}'
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
            name      = "jfs-metadata-tls"
            mountPath = local.cert_path
            subPath   = basename(local.cert_path)
          },
          {
            name      = "jfs-metadata-tls"
            mountPath = local.key_path
            subPath   = basename(local.key_path)
          },
          {
            name      = "jfs-metadata-tls"
            mountPath = local.ca_cert_path
            subPath   = basename(local.ca_cert_path)
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
            '${local.metadata_url}' \
            ${var.jfs_mount_path} \
            --storage minio \
            --bucket ${local.jfs_bucket} \
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
            name      = "jfs-metadata-tls"
            mountPath = local.cert_path
            subPath   = basename(local.cert_path)
          },
          {
            name      = "jfs-metadata-tls"
            mountPath = local.key_path
            subPath   = basename(local.key_path)
          },
          {
            name      = "jfs-metadata-tls"
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
      {
        name = "jfs-metadata-tls"
        secret = {
          secretName = module.secret.name
        }
      }
    ])
  })
}
