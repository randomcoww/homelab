
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
        name       = "flowise"
        port       = local.extra_configs.PORT
        protocol   = "TCP"
        targetPort = local.extra_configs.PORT
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
            sync-interval     = "100ms"
            snapshot-interval = "1h"
            retention         = "1h"
          },
        ]
      },
    ]
  }
  sqlite_path         = local.db_path
  minio_access_secret = var.minio_access_secret
  ca_bundle_configmap = var.ca_bundle_configmap
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
          ], [
          {
            name = "S3_STORAGE_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "S3_STORAGE_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
        ])
        ports = [
          {
            containerPort = local.extra_configs.PORT
          },
        ]
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = "/etc/ssl/certs/ca-certificates.crt"
            subPath   = "ca.crt"
            readOnly  = true
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
        name = "litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "ca-trust-bundle"
        configMap = {
          name = var.ca_bundle_configmap
        }
      },
    ]
  }
}