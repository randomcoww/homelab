locals {
  config_path = "/etc/litestream.yml"
}

module "metadata" {
  source  = "../../../modules/metadata"
  name    = var.name
  release = var.release
  manifests = {
    "templates/statefulset.yaml"       = module.statefulset.manifest
    "templates/secret-litestream.yaml" = module.secret.manifest
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-litestream"
  app     = var.app
  release = var.release
  data = {
    basename(local.config_path) = yamlencode(var.litestream_config)
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
        name  = "${var.name}-litestream-restore"
        image = var.images.litestream
        args = [
          "restore",
          "-if-db-not-exists",
          "-if-replica-exists",
          "-config",
          local.config_path,
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
        ]
        volumeMounts = [
          {
            name      = "litestream-config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ]
      },
      {
        name          = "${var.name}-litestream-replicate"
        image         = var.images.litestream
        restartPolicy = "Always"
        args = [
          "replicate",
          "-config",
          local.config_path,
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
            name      = "litestream-config"
            mountPath = local.config_path
            subPath   = basename(local.config_path)
          },
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ]
      },
      ], [
      for _, container in lookup(var.template_spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "litestream-data"
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
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ])
      })
    ]
    volumes = concat(lookup(var.template_spec, "volumes", []), [
      {
        name = "litestream-config"
        secret = {
          secretName = module.secret.name
        }
      },
    ])
  })
}
