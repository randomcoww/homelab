locals {
  kavita_port      = 5000
  data_path        = "/library/mnt"
  appsettings_file = "/kavita/config/appsettings.json" # not configurable
  db_file          = "/kavita/config/kavita.db"        # not configurable
  covers_path      = "/kavita/config/covers"           # not configurable
}

resource "random_bytes" "jwt-secret" {
  length = 256
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
    "appsettings.json" = jsonencode(merge({
      TokenKey      = random_bytes.jwt-secret.base64
      Port          = local.kavita_port
      IpAddresses   = "0.0.0.0"
      BaseUrl       = "/"
      Cache         = 75
      AllowIFraming = false
    }, var.extra_configs))
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
        port       = local.kavita_port
        protocol   = "TCP"
        targetPort = local.kavita_port
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
          port    = local.kavita_port
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
        memory = "12Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.kavita
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e
          echo "$APPSETTINGS" > "${local.appsettings_file}"

          exec /entrypoint.sh
          EOF
        ]
        ports = [
          {
            containerPort = local.kavita_port
          },
        ]
        env = [
          {
            name = "APPSETTINGS"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "appsettings.json"
              }
            }
          },
        ]
        livenessProbe = {
          httpGet = {
            path = "/api/health"
            port = local.kavita_port
          }
        }
        readinessProbe = {
          httpGet = {
            path = "/api/health"
            port = local.kavita_port
          }
        }
        startupProbe = {
          httpGet = {
            path = "/api/health"
            port = local.kavita_port
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

module "covers-mountpoint-s3-overlay" {
  source = "../mountpoint_s3_overlay"

  name        = "${var.name}-covers"
  app         = var.name
  release     = var.release
  mount_path  = local.covers_path
  s3_endpoint = var.minio_endpoint
  s3_bucket   = var.minio_bucket
  s3_prefix   = "covers"
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
  template_spec = module.covers-mountpoint-s3-overlay.template_spec
}