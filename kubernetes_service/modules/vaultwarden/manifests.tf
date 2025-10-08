
locals {
  vaultwarden_port = 8080
  extra_configs = merge(var.extra_configs, {
    DATABASE_URL          = "/data/db.sqlite3"
    DATABASE_CONN_INIT    = "PRAGMA busy_timeout = 5000; PRAGMA synchronous = NORMAL;"
    ROCKET_PORT           = local.vaultwarden_port
    DOMAIN                = "https://${var.service_hostname}"
    USER_ATTACHMENT_LIMIT = 0
    ORG_ATTACHMENT_LIMIT  = 0
  })
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
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
    DATA_FOLDER = dirname(local.extra_configs.DATABASE_URL)
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
        name       = "vaultwarden"
        port       = local.vaultwarden_port
        protocol   = "TCP"
        targetPort = local.vaultwarden_port
      },
    ]
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
          port    = local.vaultwarden_port
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
        path = local.extra_configs.DATABASE_URL
        replicas = [
          {
            name              = "minio"
            type              = "s3"
            endpoint          = var.minio_endpoint
            bucket            = var.minio_bucket
            path              = var.minio_litestream_prefix
            sync-interval     = "100ms"
            snapshot-interval = "1h"
            retention         = "1h"
          },
        ]
      },
    ]
  }
  sqlite_path         = local.extra_configs.DATABASE_URL
  minio_access_secret = var.minio_access_secret
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
        image = var.images.vaultwarden
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
            containerPort = local.vaultwarden_port
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.vaultwarden_port
            path   = "/alive"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.vaultwarden_port
            path   = "/alive"
          }
        }
      },
    ]
    volumes = [
      {
        name = "litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}