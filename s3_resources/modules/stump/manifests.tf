locals {
  extra_envs = merge(var.extra_configs, {
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
    STUMP_TRUST_PROXY_HEADERS     = true
    STUMP_VERBOSITY               = 0 # disable internal log file
    STUMP_ALLOWED_ORIGINS         = "https://${var.ingress_hostname}"
  })
  db_file         = "${local.extra_envs.STUMP_DB_PATH}/stump.db" # non-configurable
  data_path       = "/data"
  thumbnails_path = "${local.extra_envs.STUMP_CONFIG_DIR}/thumbnails" # non-configurable
  # juicefs for thumbnails
  juicefs_postgres_database = "juicefs"
  juicefs_postgres_user     = "juicefs"
}

resource "random_password" "juicefs-postgres-password" {
  length  = 32
  special = false
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for k, v in local.extra_envs :
    tostring(k) => tostring(v)
  }
}

module "juicefs-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-juicefs"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    # juicefs params
    name       = var.name
    metaurl    = "postgres://${local.juicefs_postgres_user}:${random_password.juicefs-postgres-password.result}@${var.name}-pg-rw.${var.namespace}/${local.juicefs_postgres_database}"
    storage    = "minio"
    bucket     = "${var.minio_endpoint}/${var.minio_bucket}"
    access-key = var.minio_user.id
    secret-key = var.minio_user.secret
    format-options = join(",", [
      "trash-days=0",
      "block-size=4096",
    ])

    # cngp params
    username = local.juicefs_postgres_user
    password = random_password.juicefs-postgres-password.result
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = local.extra_envs.STUMP_PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.STUMP_PORT
      },
    ]
  }
}

module "httproute" {
  source    = "../../../modules/httproute"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
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
            port = local.extra_envs.STUMP_PORT
          },
        ]
      },
    ]
  }
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
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
  mount_path       = dirname(local.db_file)
  s3_access_secret = module.minio-user-secret.name

  template_spec = {
    resources = {
      requests = {
        memory = "6Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.stump
        ports = [
          {
            containerPort = local.extra_envs.STUMP_PORT
          },
        ]
        envFrom = [
          {
            secretRef = {
              name = module.secret.name
            }
          },
        ]
        volumeMounts = [
          {
            name      = "data"
            mountPath = local.data_path
          },
          {
            name      = "thumbnails"
            mountPath = local.thumbnails_path
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.extra_envs.STUMP_PORT
            path = "/api/v2/ping"
          }
          timeoutSeconds   = 4
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            port = local.extra_envs.STUMP_PORT
            path = "/api/v2/ping"
          }
          timeoutSeconds = 4
        }
      },
    ]
    volumes = [
      {
        name = "${var.name}-litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "data"
        persistentVolumeClaim = {
          claimName = "${var.name}-${var.minio_data_bucket}"
        }
      },
      {
        name = "thumbnails"
        persistentVolumeClaim = {
          claimName = "${var.name}-${var.minio_bucket}"
        }
      },
    ]
  }
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = merge({
    "checksum/secret"            = sha256(module.secret.manifest)
    "checksum/juicefs-secret"    = sha256(module.juicefs-secret.manifest)
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
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
  template_spec = module.litestream-overlay.template_spec
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}