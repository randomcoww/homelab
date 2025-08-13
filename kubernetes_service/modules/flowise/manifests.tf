
locals {
  extra_configs = merge(var.extra_configs, {
    DATABASE_TYPE               = "sqlite"
    DATABASE_PATH               = "/var/lib/flowise"
    PORT                        = 3000
    SECRETKEY_STORAGE_TYPE      = "local"
    FLOWISE_SECRETKEY_OVERWRITE = random_password.flowise-secretkey-overwrite.result
    JWT_AUTH_TOKEN_SECRET       = random_password.jwt-auth-token-secret.result
    JWT_REFRESH_TOKEN_SECRET    = random_password.jwt-refresh-token-secret.result
    TOKEN_HASH_SECRET           = random_password.token-hash-secret.result
    NODE_EXTRA_CA_CERTS         = "/usr/local/share/ca-certificates/ca-cert.pem"
  })
  db_path = "${local.extra_configs.DATABASE_PATH}/database.sqlite"
}

resource "random_password" "flowise-secretkey-overwrite" {
  length  = 30
  special = false
}

resource "random_password" "jwt-auth-token-secret" {
  length  = 30
  special = false
}

resource "random_password" "jwt-refresh-token-secret" {
  length  = 30
  special = false
}

resource "random_password" "token-hash-secret" {
  length  = 30
  special = false
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.flowise)[1]
  manifests = merge(module.litestream.chart.manifests, {
    "templates/secret.yaml"  = module.secret.manifest
    "templates/service.yaml" = module.service.manifest
    "templates/ingress.yaml" = module.ingress.manifest
  })
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    for k, v in local.extra_configs :
    tostring(k) => tostring(v)
    }, {
    trusted_ca = var.trusted_ca
  })
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
        name       = "open-webui"
        port       = local.extra_configs.PORT
        protocol   = "TCP"
        targetPort = local.extra_configs.PORT
      },
    ]
    sessionAffinity = "ClientIP"
    sessionAffinityConfig = {
      clientIP = {
        timeoutSeconds = 10800
      }
    }
  }
}

module "ingress" {
  source             = "../../../modules/ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = local.extra_configs.PORT
          path    = "/"
        },
      ]
    },
  ]
}

module "litestream" {
  source = "../statefulset_litestream"
  ## litestream settings
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path = local.db_path
        replicas = [
          {
            name              = "minio"
            type              = "s3"
            endpoint          = var.minio_endpoint
            bucket            = var.minio_bucket
            path              = var.minio_litestream_prefix
            access-key-id     = var.minio_access_key_id
            secret-access-key = var.minio_secret_access_key
            sync-interval     = "100ms"
            snapshot-interval = "1h"
            retention         = "1h"
          },
        ]
      },
    ]
  }
  sqlite_path = local.db_path
  ##
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.flowise
        env = [
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
        ]
        ports = [
          {
            containerPort = local.extra_configs.PORT
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.extra_configs.NODE_EXTRA_CA_CERTS
            subPath   = "trusted_ca"
          },
        ]
        readinessProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/api/v1/ping"
          }
          initialDelaySeconds = 0
          periodSeconds       = 10
          timeoutSeconds      = 1
          failureThreshold    = 3
          successThreshold    = 1
        }
        livenessProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/api/v1/ping"
          }
          initialDelaySeconds = 0
          periodSeconds       = 10
          timeoutSeconds      = 1
          failureThreshold    = 3
          successThreshold    = 1
        }
      },
    ]
    volumes = [
      {
        name     = "litestream-data"
        emptyDir = {}
      },
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}