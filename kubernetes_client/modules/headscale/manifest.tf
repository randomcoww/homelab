locals {
  db_path                = "/data/db.sqlite3"
  base_path              = "/etc/headscale"
  config_path            = "${local.base_path}/config.yaml"
  private_key_path       = "${local.base_path}/private.key"
  noise_private_key_path = "${local.base_path}/noise_private.key"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.headscale)[1]
  manifests = {
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    ACCESS_KEY_ID       = var.s3_access_key_id
    SECRET_ACCESS_KEY   = var.s3_secret_access_key
    "private.key"       = "privkey:${var.private_key}"
    "noise_private.key" = "privkey:${var.noise_private_key}"
    "config.yaml" = yamlencode(merge(var.extra_config, {
      server_url       = "http://${var.service_hostname}"
      listen_addr      = "0.0.0.0:${var.ports.headscale}"
      grpc_listen_addr = "0.0.0.0:${var.ports.headscale_grpc}"
      private_key_path = local.private_key_path
      noise = {
        private_key_path = local.noise_private_key_path
      }
      db_type = "sqlite3"
      db_path = local.db_path
    }))
  })
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
        name       = "headscale"
        port       = var.ports.headscale
        protocol   = "TCP"
        targetPort = var.ports.headscale
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
          port    = var.ports.headscale
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
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
                name = module.secret.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "LITESTREAM_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "headscale-data"
            mountPath = dirname(local.db_path)
          },
        ]
      }
    ]
    containers = [
      {
        name  = var.name
        image = var.images.headscale
        args = [
          "headscale",
          "serve",
          "-c",
          local.config_path,
        ]
        volumeMounts = [
          {
            name      = "headscale-data"
            mountPath = dirname(local.db_path)
          },
          {
            name      = "secret"
            mountPath = local.config_path
            subPath   = "config.yaml"
          },
          {
            name      = "secret"
            mountPath = local.private_key_path
            subPath   = "private.key"
          },
          {
            name      = "secret"
            mountPath = local.noise_private_key_path
            subPath   = "noise_private.key"
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
                name = module.secret.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "LITESTREAM_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "headscale-data"
            mountPath = dirname(local.db_path)
          },
        ]
      },
    ]
    volumes = [
      {
        name = "headscale-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "secret"
        secret = {
          secretName = module.secret.name
        }
      },
    ]
  }
}