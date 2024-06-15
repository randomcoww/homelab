locals {
  config_path = "/etc/litestream.yml"
}

module "secret" {
  source  = "../secret"
  name    = "${var.name}-litestream"
  app     = var.app
  release = var.release
  data = {
    basename(local.config_path) = yamlencode(var.litestream_config)
  }
}

module "statefulset" {
  source            = "../statefulset"
  name              = var.name
  app               = var.app
  release           = var.release
  replicas          = 1
  min_ready_seconds = var.min_ready_seconds
  annotations = merge({
    "checksum/${module.secret.name}" = sha256(module.secret.manifest)
  }, var.annotations)
  affinity    = var.affinity
  tolerations = var.tolerations
  spec = merge(var.spec, {
    initContainers = concat([
      {
        name  = "${var.name}-litestream-restore"
        image = var.litestream_image
        args = [
          "restore",
          "-if-db-not-exists",
          "-if-replica-exists",
          "-config",
          local.config_path,
          var.sqlite_path,
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
      for _, container in lookup(var.spec, "initContainers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ])
      })
    ])
    containers = concat([
      {
        name  = "${var.name}-litestream-replica"
        image = var.litestream_image
        args = [
          "replicate",
          "-config",
          local.config_path,
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
      for _, container in lookup(var.spec, "containers", []) :
      merge(container, {
        volumeMounts = concat(lookup(container, "volumeMounts", []), [
          {
            name      = "litestream-data"
            mountPath = dirname(var.sqlite_path)
          },
        ])
      })
    ])
    volumes = concat(lookup(var.spec, "volumes", []), [
      {
        name = "litestream-config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ])
  })
  volume_claim_templates = var.volume_claim_templates
}
