output "additional_manifests" {
  value = [
    module.secret.manifest,
  ]
}

output "template_spec" {
  value = merge(var.template_spec, {
    initContainers = concat([
      {
        name  = "${var.name}-litestream-restore"
        image = var.images.litestream
        args = [
          "restore",
          "-if-db-not-exists",
          "-if-replica-exists",
          "-config",
          local.config_file,
          var.sqlite_path,
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
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
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
            mountPath = dirname(var.sqlite_path)
          },
          {
            name      = "${var.name}-litestream-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
      },
      {
        name          = "${var.name}-litestream-replicate"
        image         = var.images.litestream
        restartPolicy = "Always" # sidecar mode
        args = [
          "replicate",
          "-config",
          local.config_file,
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
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
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
            mountPath = dirname(var.sqlite_path)
          },
          {
            name      = "${var.name}-litestream-ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            readOnly  = true
          },
        ]
        resources = var.litestream_resources
        # TODO: add health checks
      },
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "${var.name}-litestream-data"
            mountPath = dirname(var.sqlite_path)
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
            mountPath = dirname(var.sqlite_path)
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
  })
}