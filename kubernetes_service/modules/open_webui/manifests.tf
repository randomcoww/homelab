
locals {
  db_path          = "/data/db.sqlite3"
  extra_configs = merge(var.extra_configs, {
    PORT = 8080
    DATABASE_URL = "sqlite://${local.db_path}"
  })
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.open_webui)[1]
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
        name       = "open_webui"
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
        image = var.images.open_webui
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
        startupProbe = {
          httpGet = {
            port   = local.extra_configs.PORT
            path   = "/health"
          }
          initialDelaySeconds = 30
          periodSeconds = 5
          failureThreshold = 20
        }
        readinessProbe = {
          httpGet = {
            port   = local.extra_configs.PORT
            path   = "/health/db"
          }
          failureThreshold = 1
          periodSeconds = 10
        }
        livenessProbe = {
          httpGet = {
            port   = local.extra_configs.PORT
            path   = "/health"
          }
          failureThreshold = 1
          periodSeconds = 10
        }
      },
    ]
    volumes = [
      {
        name     = "litestream-data"
        emptyDir = {}
      },
    ]
  }
}