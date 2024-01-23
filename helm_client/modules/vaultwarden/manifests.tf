locals {
  db_path = "/data/db.sqlite3"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.vaultwarden)[1]
  manifests = {
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    ACCESS_KEY_ID     = var.s3_access_key_id
    SECRET_ACCESS_KEY = var.s3_secret_access_key
    SMTP_USERNAME     = var.smtp_username
    SMTP_PASSWORD     = var.smtp_password
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
        port       = var.ports.vaultwarden
        protocol   = "TCP"
        targetPort = var.ports.vaultwarden
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
  cert_issuer        = var.ingress_cert_issuer
  auth_url           = var.ingress_auth_url
  auth_signin        = var.ingress_auth_signin
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = var.ports.vaultwarden
          path    = "/"
        }
      ]
    },
  ]
}

module "deployment" {
  source   = "../deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    dnsPolicy = "ClusterFirstWithHostNet"
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.litestream
        args = [
          "restore",
          "-if-replica-exists",
          "-o",
          local.db_path,
          "s3://${var.s3_db_resource}",
        ]
        env = [
          {
            name = "LITESTREAM_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "LITESTREAM_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "vaultwarden-data"
            mountPath = dirname(local.db_path)
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.vaultwarden
        env = concat([
          {
            name  = "DATA_FOLDER"
            value = dirname(local.db_path)
          },
          {
            name  = "DATABASE_URL"
            value = local.db_path
          },
          {
            name  = "ROCKET_PORT"
            value = tostring(var.ports.vaultwarden)
          },
          {
            name  = "DOMAIN"
            value = "https://${var.service_hostname}"
          },
          {
            name  = "SMTP_HOST"
            value = var.smtp_host
          },
          {
            name  = "SMTP_PORT"
            value = var.smtp_port
          },
          {
            name = "SMTP_FROM"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SMTP_USERNAME"
              }
            }
          },
          {
            name = "SMTP_USERNAME"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SMTP_USERNAME"
              }
            }
          },
          {
            name = "SMTP_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SMTP_PASSWORD"
              }
            }
          },
          ], [
          for k, v in var.exrtra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ])
        volumeMounts = [
          {
            name      = "vaultwarden-data"
            mountPath = dirname(local.db_path)
          },
        ]
        ports = [
          {
            containerPort = var.ports.vaultwarden
          },
        ]
      },
      {
        name  = "${var.name}-litestream"
        image = var.images.litestream
        args = [
          "replicate",
          local.db_path,
          "s3://${var.s3_db_resource}",
        ]
        env = [
          {
            name = "LITESTREAM_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "LITESTREAM_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "vaultwarden-data"
            mountPath = dirname(local.db_path)
          },
        ]
      },
    ]
    volumes = [
      {
        name = "vaultwarden-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}