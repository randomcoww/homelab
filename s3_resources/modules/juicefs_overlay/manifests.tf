locals {
  cache_path          = "/var/jfsCache"
  db_path             = "${local.cache_path}/jfs.db" # https://juicefs.com/docs/community/guide/cache/#cache-dir
  db_url              = "sqlite3://${local.db_path}?_busy_timeout=5000&_synchronous=NORMAL&_wal_autocheckpoint=0"
  mount_path_internal = "/${var.name}-juicefs/mnt"
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name      = "${var.name}-juicefs"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path                = local.db_path
        monitor-interval    = "1s"
        checkpoint-interval = "60s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = join("/", compact(split("/", "${var.minio_prefix}/litestream")))
          sync-interval = "1s"
          part-size     = "50MB"
          concurrency   = 10
          auto-recover  = true
        }
      },
    ]
  }
  mount_path       = local.cache_path
  s3_access_secret = var.minio_access_secret

  template_spec = var.template_spec
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