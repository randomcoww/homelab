locals {
  config_file = "${var.mount_path}/config.yaml"
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