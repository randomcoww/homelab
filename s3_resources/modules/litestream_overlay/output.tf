output "additional_manifests" {
  value = [
    module.secret.manifest,
  ]
}

output "template_spec" {
  value = merge(var.template_spec, {
    initContainers = concat([
      for i, db in var.litestream_config.dbs :
      merge({
        name  = "${var.name}-litestream-restore-${i}"
        image = var.images.litestream
        args = [
          "restore",
          "-if-db-not-exists",
          "-if-replica-exists",
          "-config",
          local.config_file,
          db.path,
        ]
        envFrom = [
          {
            secretRef = {
              name = var.s3_access_secret
            }
          },
        ]
        env = [
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
            name      = "${var.name}-litestream-config"
            mountPath = local.config_file
            subPath   = "config.yaml"
          },
          {
            name      = "${var.name}-litestream-data"
            mountPath = var.mount_path
          },
          {
            name      = "${var.name}-litestream-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
      }, var.litestream_container_params)
      ], [
      merge({
        name          = "${var.name}-litestream-replicate"
        image         = var.images.litestream
        restartPolicy = "Always" # sidecar mode
        args = [
          "replicate",
          "-config",
          local.config_file,
        ]
        envFrom = [
          {
            secretRef = {
              name = var.s3_access_secret
            }
          },
        ]
        env = [
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
            name      = "${var.name}-litestream-config"
            mountPath = local.config_file
            subPath   = "config.yaml"
          },
          {
            name      = "${var.name}-litestream-data"
            mountPath = var.mount_path
          },
          {
            name      = "${var.name}-litestream-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        resources = {
          requests = {
            memory = "128Mi"
          }
        }
        livenessProbe = {
          exec = {
            command = [
              "sh",
              "-c",
              <<-EOF
              if ! litestream status -config ${local.config_file} | tail -n +2 | awk '{print $2}' | grep -q 'error'; then
                exit 0
              fi
              exit 1
              EOF
            ]
          }
          timeoutSeconds = 2
        }
        startupProbe = {
          exec = {
            command = [
              "sh",
              "-c",
              <<-EOF
              if ! litestream status -config ${local.config_file} | tail -n +2 | awk '{print $2}' | grep -q 'error'; then
                exit 0
              fi
              exit 1
              EOF
            ]
          }
          periodSeconds    = 2
          failureThreshold = 12
        }
      }, var.litestream_container_params)
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-litestream-data"
            mountPath = var.mount_path
          },
        ])
      })
    ])
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-litestream-data"
            mountPath = var.mount_path
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "${var.name}-litestream-config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "${var.name}-litestream-ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ])
    terminationGracePeriodSeconds = 60
  })
}