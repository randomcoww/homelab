locals {
  config_file = "/etc/litestream/config.yaml"
}

module "secret" {
  source  = "../../../modules/secret"
  name    = "${var.name}-litestream"
  app     = var.app
  release = var.release
  data = {
    "config.yaml" = yamlencode(var.litestream_config)
  }
}

/*
volumeClaimTemplates = [
  {
    metadata = {
      name = "${var.name}-litestream-data"
    }
    spec = {
      accessModes = [
        "ReadWriteOnce",
      ]
      resources = {
        requests = {
          storage = "16Gi"
        }
      }
      storageClassName = "local-path"
    }
  },
]
*/