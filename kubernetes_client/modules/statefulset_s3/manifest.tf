module "metadata" {
  source  = "../metadata"
  name    = var.name
  release = var.release
  manifests = {
    "templates/statefulset.yaml"     = module.statefulset.manifest
    "templates/secret-s3-mount.yaml" = module.secret.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = "${var.name}-s3-mount"
  app     = var.app
  release = var.release
  data = {
    AWS_ACCESS_KEY_ID     = var.s3_mount_access_key_id
    AWS_SECRET_ACCESS_KEY = var.s3_mount_secret_access_key
  }
}

module "statefulset" {
  source      = "../statefulset"
  name        = var.name
  app         = var.app
  release     = var.release
  replicas    = var.replicas
  affinity    = var.affinity
  tolerations = var.tolerations
  spec        = var.spec
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      {
        name          = "${var.name}-s3-mount"
        image         = var.images.mountpoint
        restartPolicy = "Always"
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mkdir -p ${var.s3_mount_path}
          mount-s3 \
            -f \
            --endpoint-url ${var.s3_mount_endpoint} \
            --allow-delete \
            --allow-overwrite \
            --auto-unmount \
            --allow-other \
            --no-log \
            --prefix $(POD_NAME)/ \
            %{~for arg in var.s3_mount_extra_args~}
            ${arg} \
            %{~endfor~}
            ${var.s3_mount_bucket} \
            ${var.s3_mount_path}
          EOF
        ]
        env = [
          {
            name = "AWS_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "AWS_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
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
            name             = "s3-mount-shared"
            mountPath        = dirname(var.s3_mount_path)
            mountPropagation = "Bidirectional"
          },
        ]
        securityContext = {
          privileged = true
        }
      },
    ], lookup(var.template_spec, "initContainers", []))
    containers = [
      for _, container in lookup(var.template_spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "s3-mount-shared"
            mountPath = dirname(var.s3_mount_path)
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "s3-mount-shared"
        emptyDir = {
          medium = "Memory"
        }
      },
    ])
  })
}