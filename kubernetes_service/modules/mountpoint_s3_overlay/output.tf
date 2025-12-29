locals {
  mount_path_internal = "/${var.name}-mountpoint-s3/mnt"
}

output "template_spec" {
  value = merge(var.template_spec, {
    initContainers = concat([
      {
        name          = "${var.name}-mountpoint-mount"
        image         = var.images.mountpoint
        restartPolicy = "Always" # sidecar mode
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mkdir -p ${local.mount_path_internal}
          exec mount-s3 \
            -f \
            --endpoint-url ${var.s3_endpoint} \
            --allow-delete \
            --allow-overwrite \
            --auto-unmount \
            --allow-other \
            --maximum-throughput-gbps 1 \
            %{~if length(var.s3_prefix) > 0~}
            --prefix ${var.s3_prefix}/ \
            %{~endif~}
            %{~for arg in var.s3_mount_extra_args~}
            ${arg} \
            %{~endfor~}
            ${var.s3_bucket} \
            ${local.mount_path_internal}
          EOF
        ]
        env = [
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.s3_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.s3_access_secret
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
            name             = "${var.name}-mountpoint-shared"
            mountPath        = dirname(local.mount_path_internal)
            mountPropagation = "Bidirectional"
          },
          {
            name      = "${var.name}-mountpoint-tmp"
            mountPath = "/var/tmp"
          },
          {
            name      = "${var.name}-mountpoint-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        securityContext = {
          privileged = true
        }
        startupProbe = {
          exec = {
            command = [
              "/usr/bin/mountpoint",
              local.mount_path_internal,
            ]
          }
          periodSeconds    = 2
          failureThreshold = 12
        }
      },
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-mountpoint-shared"
            mountPath = var.mount_path
            subPath   = basename(local.mount_path_internal)
          },
        ])
      })
    ])
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-mountpoint-shared"
            mountPath = var.mount_path
            subPath   = basename(local.mount_path_internal)
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "${var.name}-mountpoint-shared"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "${var.name}-mountpoint-tmp"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "${var.name}-mountpoint-ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ])
  })
}