locals {
  extra_configs = merge(var.extra_configs, {
    STUMP_CONFIG_DIR              = "/stump/config"
    STUMP_DB_PATH                 = "/stump/data"
    STUMP_PORT                    = 8000
    STUMP_OIDC_ENABLED            = true
    STUMP_OIDC_ALLOW_REGISTRATION = true
    STUMP_OIDC_DISABLE_LOCAL_AUTH = true
    ENABLE_SWAGGER_UI             = false
    ENABLE_KOREADER_SYNC          = false
    ENABLE_OPDS_PROGRESSION       = false
    STUMP_ENABLE_UPLOAD           = false
    STUMP_PRETTY_LOGS             = false
    STUMP_VERBOSITY               = 1
    STUMP_ALLOWED_ORIGINS         = "https://${var.ingress_hostname}"
  })
  db_file         = "${local.extra_configs.STUMP_DB_PATH}/stump.db" # non-configurable
  data_path       = "/data"
  thumbnails_path = "${local.extra_configs.STUMP_CONFIG_DIR}/thumbnails" # non-configurable

  manifests = concat([
    module.statefulset.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
  ], module.litestream-overlay.additional_manifests)
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for k, v in local.extra_configs :
    tostring(k) => tostring(v)
  }
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = local.extra_configs.STUMP_PORT
        protocol   = "TCP"
        targetPort = local.extra_configs.STUMP_PORT
      },
    ]
  }
}

module "httproute" {
  source  = "../../../modules/httproute"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    parentRefs = [
      merge({
        kind = "Gateway"
      }, var.gateway_ref),
    ]
    hostnames = [
      var.ingress_hostname,
    ]
    rules = [
      {
        matches = [
          {
            path = {
              type  = "PathPrefix"
              value = "/"
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.extra_configs.STUMP_PORT
          },
        ]
      },
    ]
  }
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name    = var.name
  app     = var.name
  release = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path                = local.db_file
        monitor-interval    = "1s"
        checkpoint-interval = "60s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = "$POD_NAME/litestream"
          sync-interval = "1s"
          part-size     = "50MB"
          concurrency   = 10
        }
      },
    ]
  }
  sqlite_path         = local.db_file
  minio_access_secret = var.minio_access_secret

  template_spec = {
    resources = {
      requests = {
        memory = "8Gi"
      }
      limits = {
        memory = "8Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.stump
        ports = [
          {
            containerPort = local.extra_configs.STUMP_PORT
          },
        ]
        env = concat([
          for k, v in local.extra_configs :
          {
            name = tostring(k)
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = tostring(k)
              }
            }
          }
        ])
        # TODO: add healthchecks
      },
    ]
    volumes = [
      {
        name = "${var.name}-litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}

module "mountpoint-s3-overlay" {
  source = "../mountpoint_s3_overlay"

  name        = var.name
  app         = var.name
  release     = var.release
  mount_path  = local.data_path
  s3_endpoint = var.minio_endpoint
  s3_bucket   = var.minio_data_bucket
  s3_prefix   = ""
  s3_mount_extra_args = [
    "--read-only",
    # "--cache /var/cache", # cache to disk
    "--cache /var/tmp",      # cache to memory
    "--max-cache-size 1024", # 1Gi
  ]
  s3_access_secret = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }
  template_spec = module.litestream-overlay.template_spec
}

module "thumbnails-mountpoint-s3-overlay" {
  source = "../mountpoint_s3_overlay"

  name        = "${var.name}-thumbnails"
  app         = var.name
  release     = var.release
  mount_path  = local.thumbnails_path
  s3_endpoint = var.minio_endpoint
  s3_bucket   = var.minio_bucket
  s3_prefix   = "thumbnails"
  s3_mount_extra_args = [
    # cache may be causing some cover generation to fail
  ]
  s3_access_secret = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }
  template_spec = module.mountpoint-s3-overlay.template_spec
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = merge({
    "checksum/secret" = sha256(module.secret.manifest)
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "checksum/litestream-${i}" => sha256(m)
  })
  /* persistent path for sqlite
  spec = {
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
  }
  */
  template_spec = module.thumbnails-mountpoint-s3-overlay.template_spec
}