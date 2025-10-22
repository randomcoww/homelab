output "additional_manifests" {
  value = module.litestream-overlay.additional_manifests
}

output "template_spec" {
  value = merge(module.litestream-overlay.template_spec, {
    initContainers = concat([
      {
        name  = "${var.name}-juicefs-format"
        image = var.images.juicefs
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
            ${var.minio_prefix} \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --trash-days=0 \
            --capacity=${var.capacity_gb}

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
        volumeMounts = [
          {
            name      = "${var.name}-juicefs-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
          },
        ]
      },
      {
        name          = "${var.name}-juicefs-mount"
        image         = var.images.juicefs
        restartPolicy = "Always"
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          mkdir -p ${var.mount_path}

          exec juicefs mount '${local.db_url}' \
            ${var.mount_path} \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --no-syslog \
            --atime-mode=noatime \
            --backup-meta=0 \
            --no-usage-report=true \
            --writeback \
            --cache-dir=${dirname(local.db_path)} \
            -o allow_other,noatime
          EOF
        ]
        volumeMounts = [
          {
            name             = "${var.name}-juicefs-shared"
            mountPath        = dirname(var.mount_path)
            mountPropagation = "Bidirectional"
          },
          {
            name      = "${var.name}-juicefs-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
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
            name             = "${var.name}-juicefs-shared"
            mountPath        = dirname(var.mount_path)
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
            name             = "${var.name}-juicefs-shared"
            mountPath        = dirname(var.mount_path)
            mountPropagation = "HostToContainer"
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "${var.name}-juicefs-ca-trust-bundle"
        configMap = {
          name = var.ca_bundle_configmap
        }
      },
      {
        name = "${var.name}-juicefs-shared"
        emptyDir = {
          medium = "Memory"
        }
      },
    ])
  })
}