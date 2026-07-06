locals {
  db_file = "/data/db.sqlite3"
  extra_envs = merge(var.extra_configs, {
    CORS_ALLOW_ORIGIN                  = "https://${var.ingress_hostname}"
    PORT                               = 8080
    REQUESTS_CA_BUNDLE                 = "/etc/ssl/certs/ca-certificates.crt"
    SSL_CERT_FILE                      = "/etc/ssl/certs/ca-certificates.crt" # needed for tools server TLS
    STORAGE_PROVIDER                   = "s3"
    S3_ADDRESSING_STYLE                = "path"
    S3_KEY_PREFIX                      = "data"
    S3_BUCKET_NAME                     = var.minio_bucket
    S3_ENDPOINT_URL                    = var.minio_endpoint
    WEBUI_SECRET_KEY                   = random_password.webui-secret-key.result
    OAUTH_CLIENT_INFO_ENCRYPTION_KEY   = random_password.client-info-encryption-key.result
    OAUTH_SESSION_TOKEN_ENCRYPTION_KEY = random_password.session-token-encryption-key.result
  })
}

resource "random_password" "webui-secret-key" {
  length  = 64
  special = false
}

resource "random_password" "client-info-encryption-key" {
  length  = 64
  special = false
}

resource "random_password" "session-token-encryption-key" {
  length  = 64
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
        name       = "open-webui"
        port       = local.extra_envs.PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.PORT
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
            port = local.extra_envs.PORT
          },
        ]
      },
    ]
  }
}

module "deployment" {
  source = "../../../modules/deployment"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret"            = sha256(module.secret.manifest)
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "4Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.open_webui
        env = concat([
          for k, v in local.extra_envs :
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
            name = "S3_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = module.minio-user-secret.name
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "S3_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.minio-user-secret.name
                key  = "AWS_SECRET_ACCESS_KEY"
              }
            }
          },
          {
            name = "DATABASE_URL"
            valueFrom = {
              secretKeyRef = {
                name = "${var.name}-pg-app"
                key  = "uri"
              }
            }
          },
        ])
        ports = [
          {
            containerPort = local.extra_envs.PORT
          },
        ]
        volumeMounts = [
          {
            name      = "ca-trust-bundle"
            mountPath = local.extra_envs.REQUESTS_CA_BUNDLE
            readOnly  = true
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.extra_envs.PORT
            path = "/health"
          }
          timeoutSeconds = 2
        }
        readinessProbe = {
          httpGet = {
            port = local.extra_envs.PORT
            path = "/health/db"
          }
        }
        startupProbe = {
          httpGet = {
            port = local.extra_envs.PORT
            path = "/health"
          }
          failureThreshold = 6
        }
      },
    ]
    volumes = [
      {
        name = "ca-trust-bundle"
        hostPath = {
          path = "/etc/ssl/certs/ca-certificates.crt"
          type = "File"
        }
      },
    ]
  }
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