module "metadata" {
  source  = "../../../modules/metadata"
  name    = var.name
  release = var.release
  manifests = {
    "templates/statefulset.yaml"       = module.statefulset.manifest
    "templates/secret-s3fs-mount.yaml" = module.secret.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-s3fs-mount"
  app     = var.app
  release = var.release
  data = {
    AWS_ACCESS_KEY_ID     = var.s3_access_key_id
    AWS_SECRET_ACCESS_KEY = var.s3_secret_access_key
  }
}

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.app
  release  = var.release
  replicas = var.replicas
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
  affinity    = var.affinity
  tolerations = var.tolerations
  spec        = var.spec
  template_spec = merge(var.template_spec, {
    initContainers = concat([
      {
        name          = "${var.name}-s3fs-mount"
        image         = var.images.s3fs
        restartPolicy = "Always"
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mkdir -p ${var.s3_mount_path}
          exec s3fs \
            ${var.s3_bucket}%{if length(var.s3_prefix) > 0}:/${var.s3_prefix}%{endif} \
            ${var.s3_mount_path} \
            -f \
            %{~for _, arg in var.s3_mount_extra_args~}
            -o ${arg} \
            %{~endfor~}
            -o url=${var.s3_endpoint}
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
            name             = "s3fs-mount-shared"
            mountPath        = dirname(var.s3_mount_path)
            mountPropagation = "Bidirectional"
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
            name             = "s3fs-mount-shared"
            mountPath        = dirname(var.s3_mount_path)
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
            name             = "s3fs-mount-shared"
            mountPath        = dirname(var.s3_mount_path)
            mountPropagation = "HostToContainer"
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name     = "s3fs-mount-shared"
        emptyDir = {}
      },
    ])
  })
}