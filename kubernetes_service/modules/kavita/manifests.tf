locals {
  kavita_port = 5000
  data_path   = "/var/lib/kavita/mnt"
  db_path     = "/kavita/config/kavita.db"
}

resource "random_bytes" "jwt_secret" {
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
    "appsettings.json" = jsonencode({
      TokenKey      = random_bytes.jwt_secret.base64
      Port          = local.kavita_port
      IpAddresses   = "0.0.0.0"
      BaseUrl       = "/"
      Cache         = 75
      AllowIFraming = false
      OpenIdConnectSettings = { # TODO: configure OIDC
        Authority    = ""
        ClientId     = "kavita"
        Secret       = ""
        CustomScopes = []
        Enabled      = false
      }
    })
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
      host = var.service_hostname
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
        path                = local.db_path
        monitor-interval    = "100ms"
        checkpoint-interval = "6s"
        replicas = [
          {
            name          = "minio"
            type          = "s3"
            endpoint      = var.minio_endpoint
            bucket        = var.minio_litestream_bucket
            path          = var.minio_litestream_prefix
            sync-interval = "100ms"
          },
        ]
      },
    ]
  }

  sqlite_path         = local.db_path
  minio_access_secret = var.minio_access_secret
  ca_bundle_configmap = var.ca_bundle_configmap

  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.kavita
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          until mountpoint ${local.data_path}; do
          sleep 1
          done
          echo "$APPSETTINGS" > "${dirname(local.db_path)}/appsettings.json"

          exec /entrypoint.sh
          EOF
        ]
        resources = var.resources
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
      },
    ]
    volumes = [
      # Use local-path for this
      # {
      #   name     = "${var.name}-litestream-data"
      #   emptyDir = {
      #     medium = "Memory"
      #   }
      # },
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
  s3_bucket   = var.minio_bucket
  s3_prefix   = ""
  s3_mount_extra_args = concat(var.minio_mount_extra_args, [
    "--cache ${dirname(local.data_path)}",
  ])
  s3_access_secret = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }
  ca_bundle_configmap = var.ca_bundle_configmap

  template_spec = module.litestream-overlay.template_spec
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
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
  template_spec = module.mountpoint-s3-overlay.template_spec
}