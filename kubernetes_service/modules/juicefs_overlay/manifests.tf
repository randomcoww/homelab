locals {
  db_path = "/var/jfsCache/jfs.db" # https://juicefs.com/docs/community/guide/cache/#cache-dir
  db_url  = "sqlite3://${local.db_path}?_busy_timeout=5000&_synchronous=NORMAL&_wal_autocheckpoint=0"
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name    = "${var.name}-juicefs"
  app     = var.name
  release = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path                = local.db_path
        monitor-interval    = "100ms"
        checkpoint-interval = "6s"
        replicas = [
          {
            name          = "minio"
            type          = "s3"
            endpoint      = var.minio_endpoint
            bucket        = var.minio_bucket
            path          = join("/", compact(split("/", "${var.minio_prefix}/litestream")))
            sync-interval = "100ms"
          },
        ]
      },
    ]
  }

  sqlite_path         = local.db_path
  minio_access_secret = var.minio_access_secret
  ca_bundle_configmap = var.ca_bundle_configmap
  template_spec       = var.template_spec
}

/*
volumeClaimTemplates = [
  {
    metadata = {
      name = "${var.name}-juicefs-litestream-data"
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