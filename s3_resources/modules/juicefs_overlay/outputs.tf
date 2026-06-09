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
          mkdir -p ${local.cache_path}

          juicefs format '${local.db_url}' \
            ${var.minio_prefix} \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --access-key=$ACCESS_KEY \
            --secret-key=$SECRET_KEY \
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
            readOnly  = true
          },
          {
            name      = "${var.name}-juicefs-litestream-data" # this path is also used for juicefs cache
            mountPath = local.cache_path
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
          mkdir -p ${local.mount_path_internal}

          exec juicefs mount \
            -o ${join(",", concat(var.mount_extra_opts, ["allow_other", "noatime"]))} \
            '${local.db_url}' \
            ${local.mount_path_internal} \
            --storage=minio \
            --bucket=${var.minio_endpoint}/${var.minio_bucket} \
            --no-syslog \
            --atime-mode=noatime \
            --backup-meta=0 \
            --no-usage-report=true \
            --writeback \
            --cache-dir=${local.cache_path}
          EOF
        ]
        volumeMounts = [
          {
            name             = "${var.name}-juicefs-shared"
            mountPath        = dirname(local.mount_path_internal)
            mountPropagation = "Bidirectional"
          },
          {
            name      = "${var.name}-juicefs-litestream-data" # this path is also used for juicefs cache
            mountPath = local.cache_path
          },
          {
            name      = "${var.name}-juicefs-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        lifecycle = {
          preStop = {
            exec = {
              command = [
                "juicefs",
                "umount",
                "--flush",
                local.mount_path_internal,
              ]
            }
          }
        }
        securityContext = {
          privileged = true
        }
        startupProbe = {
          exec = {
            command = [
              "mountpoint",
              local.mount_path_internal,
            ]
          }
          periodSeconds    = 2
          failureThreshold = 12
        }
        livenessProbe = {
          exec = {
            command = [
              "stat",
              local.mount_path_internal,
            ]
          }
          timeoutSeconds = 4
        }
      },
      ], [
      for _, container in lookup(module.litestream-overlay.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-juicefs-shared"
            mountPath = var.mount_path
            subPath   = basename(local.mount_path_internal)
          },
        ])
      })
    ])
    containers = [
      for _, container in lookup(module.litestream-overlay.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-juicefs-shared"
            mountPath = var.mount_path
            subPath   = basename(local.mount_path_internal)
          },
        ])
      })
    ]
    volumes = concat(lookup(module.litestream-overlay.template_spec, "volumes", []), [
      {
        name = "${var.name}-juicefs-shared"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "${var.name}-juicefs-ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ])
  })
}