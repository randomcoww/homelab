locals {
  db_file         = "/data/db.sqlite3"
  playwright_port = 3000
  extra_configs = merge(var.extra_configs, {
    PORT                       = 8080
    REQUESTS_CA_BUNDLE         = "/etc/ssl/certs/ca-certificates.crt"
    SSL_CERT_FILE              = "/etc/ssl/certs/ca-certificates.crt" # needed for tools server TLS
    DATABASE_URL               = "sqlite:///${local.db_file}"
    DATABASE_ENABLE_SQLITE_WAL = true
    STORAGE_PROVIDER           = "s3"
    S3_ADDRESSING_STYLE        = "path"
    S3_KEY_PREFIX              = "data"
    S3_BUCKET_NAME             = var.minio_bucket
    S3_ENDPOINT_URL            = var.minio_endpoint
    WEBUI_SECRET_KEY           = random_password.webui-secret-key.result
    WEB_LOADER_ENGINE          = "playwright"
    PLAYWRIGHT_WS_URL          = "ws://127.0.0.1:${local.playwright_port}"
  })
}

resource "random_password" "webui-secret-key" {
  length  = 64
  special = false
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge({
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "templates/litestream-${i}.yaml" => m
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
        name       = "open-webui"
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
      host = var.ingress_hostname
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
        monitor-interval    = "100ms"
        checkpoint-interval = "6s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = "$POD_NAME/litestream"
          sync-interval = "100ms"
        }
      },
    ]
  }
  sqlite_path         = local.db_file
  minio_access_secret = var.minio_access_secret

  template_spec = {
    resources = {
      requests = {
        memory = "2Gi"
      }
      limits = {
        memory = "4Gi"
      }
    }
    initContainers = [
      {
        name          = "${var.name}-playwright"
        image         = var.images.playwright
        restartPolicy = "Always" # sidecar mode
        command = [
          "sh",
          "-c",
          <<-EOF
          npx -y playwright@1.57.0 run-server \
            --port ${local.playwright_port} \
            --host 127.0.0.1
          EOF
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.open_webui
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
            name = "S3_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.minio_access_secret
                key  = "AWS_ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "S3_SECRET_ACCESS_KEY"
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
            mountPath = local.extra_configs.REQUESTS_CA_BUNDLE
            readOnly  = true
          },
        ]
        readinessProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/health/db"
          }
          timeoutSeconds = 2
        }
        livenessProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/health"
          }
        }
        startupProbe = {
          httpGet = {
            port = local.extra_configs.PORT
            path = "/health"
          }
          failureThreshold = 6
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
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
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

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
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
  template_spec = module.litestream-overlay.template_spec
}