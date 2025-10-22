output "template_spec" {
  value = merge(var.template_spec, {
    initContainers = concat([
      {
        name          = "${var.name}-mountpoint-mount"
        image         = var.images.mountpoint
        restartPolicy = "Always"
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mkdir -p ${var.mount_path}
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
            ${var.mount_path}
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
            mountPath        = dirname(var.mount_path)
            mountPropagation = "Bidirectional"
          },
          {
            name      = "${var.name}-mountpoint-ca-trust-bundle"
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
            name             = "${var.name}-mountpoint-shared"
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
            name             = "${var.name}-mountpoint-shared"
            mountPath        = dirname(var.mount_path)
            mountPropagation = "HostToContainer"
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
        name = "${var.name}-mountpoint-ca-trust-bundle"
        configMap = {
          name = var.ca_bundle_configmap
        }
      },
    ])
  })
}