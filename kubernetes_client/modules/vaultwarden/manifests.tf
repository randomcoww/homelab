locals {
  db_path = "/data/db.sqlite3"
  extra_configs = merge(var.extra_configs, {
    DATA_FOLDER  = dirname(local.db_path)
    DATABASE_URL = local.db_path
    ROCKET_PORT  = local.ports.vaultwarden
    DOMAIN       = "https://${var.service_hostname}"
  })
  ports = {
    vaultwarden = 8080
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.vaultwarden)[1]
  manifests = {
    "templates/secret.yaml"            = module.secret.manifest
    "templates/service.yaml"           = module.service.manifest
    "templates/ingress.yaml"           = module.ingress.manifest
    "templates/statefulset.yaml"       = module.statefulset-litestream.statefulset
    "templates/secret-litestream.yaml" = module.statefulset-litestream.secret
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for k, v in local.extra_configs :
    tostring(k) => tostring(v)
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "vaultwarden"
        port       = local.ports.vaultwarden
        protocol   = "TCP"
        targetPort = local.ports.vaultwarden
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
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
          port    = local.ports.vaultwarden
          path    = "/"
        },
      ]
    },
  ]
}

module "statefulset-litestream" {
  source = "../statefulset_litestream"
  ## litestream settings
  litestream_image = var.images.litestream
  litestream_config = {
    dbs = [
      {
        path = local.db_path
        replicas = [
          {
            name                     = "minio"
            type                     = "s3"
            bucket                   = var.litestream_minio_bucket
            path                     = var.name
            endpoint                 = "http://${var.litestream_minio_endpoint}"
            access-key-id            = var.litestream_minio_access_key_id
            secret-access-key        = var.litestream_minio_secret_access_key
            retention                = "2m"
            retention-check-interval = "2m"
            sync-interval            = "500ms"
            snapshot-interval        = "1h"
          },
          {
            name              = "s3"
            url               = "s3://${var.litestream_s3_resource}/${basename(local.db_path)}"
            access-key-id     = var.litestream_s3_access_key_id
            secret-access-key = var.litestream_s3_secret_access_key
          },
        ]
      }
    ]
  }
  sqlite_path = local.db_path
  ##
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
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
            containerPort = local.ports.vaultwarden
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.vaultwarden
            path   = "/alive"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.ports.vaultwarden
            path   = "/alive"
          }
        }
      },
    ]
  }
}