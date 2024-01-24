locals {
  db_path     = "/data/db.sqlite3"
  config_path = "/etc/headscale"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.headscale)[1]
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/deployment.yaml" = module.deployment.manifest
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
    "config.yaml" = yamlencode({
      server_url          = "http://${var.service_hostname}"
      listen_addr         = "0.0.0.0:${var.ports.headscale}"
      grpc_listen_addr    = "0.0.0.0:${var.ports.headscale_grpc}"
      grpc_allow_insecure = false
      private_key_path    = "${local.config_path}/private.key"
      noise = {
        private_key_path = "${local.config_path}/noise_private.key"
      }
      ip_prefixes = [
        var.network_prefix,
      ]
      derp = {
        server = {
          enabled = false
        }
        urls = [
          "https://controlplane.tailscale.com/derpmap/default",
        ]
        paths               = []
        auto_update_enabled = true
        update_frequency    = "24h"
      }
      disable_check_updates             = false
      ephemeral_node_inactivity_timeout = "30m"
      node_update_check_interval        = "10s"
      db_type                           = "sqlite3"
      db_path                           = local.db_path
      log = {
        level = "info"
      }
      acl_policy_path = ""
      dns_config = {
        override_local_dns = false
        magic_dns          = true
      }
      logtail = {
        enabled = false
      }
      randomize_client_port = false
    })
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
          service = var.name
          port    = var.ports.headscale
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
          "${local.config_path}/config.yaml",
        ]
        volumeMounts = [
          {
            name      = "headscale-data"
            mountPath = dirname(local.db_path)
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/config.yaml"
            subPath   = "config.yaml"
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/private.key"
            subPath   = "private.key"
          },
          {
            name      = "secret"
            mountPath = "${local.config_path}/noise_private.key"
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
          secretName = var.name
        }
      },
    ]
  }
}