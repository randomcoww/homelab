
locals {
  valkey_socket_file = "/var/run/valkey/socket.sock"
  extra_configs = merge(var.extra_configs, {
    SEARXNG_SETTINGS_PATH   = "/etc/searxng/settings.yml"
    SEARXNG_LIMITER         = false
    SEARXNG_PUBLIC_INSTANCE = false
    SEARXNG_IMAGE_PROXY     = false
    SEARXNG_BIND_ADDRESS    = "0.0.0.0"
    SEARXNG_PORT            = 8080
    SEARXNG_SECRET          = random_password.searxng-secret.result
    SEARXNG_VALKEY_URL      = "unix://${local.valkey_socket_file}?db=0"
  })
}

resource "random_password" "searxng-secret" {
  length  = 30
  special = false
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
  }
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
    basename(local.extra_configs.SEARXNG_SETTINGS_PATH) = yamlencode(var.searxng_settings)
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
        name       = "searxng"
        port       = local.extra_configs.SEARXNG_PORT
        protocol   = "TCP"
        targetPort = local.extra_configs.SEARXNG_PORT
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
          port    = local.extra_configs.SEARXNG_PORT
          path    = "/"
        },
      ]
    },
  ]
}

module "deployment" {
  source   = "../../../modules/deployment"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "256Mi"
      }
      limits = {
        memory = "512Mi"
      }
    }
    initContainers = [
      {
        name          = "${var.name}-valkey"
        image         = var.images.valkey
        restartPolicy = "Always"
        args = [
          "--unixsocket",
          "${local.valkey_socket_file}",
          "--port",
          "0",
        ]
        volumeMounts = [
          {
            name      = "socket"
            mountPath = dirname(local.valkey_socket_file)
          },
        ]
        livenessProbe = {
          exec = {
            command = [
              "redis-cli",
              "-s",
              local.valkey_socket_file,
              "ping",
            ]
          }
        }
        livenessProbe = {
          exec = {
            command = [
              "redis-cli",
              "-s",
              local.valkey_socket_file,
              "ping",
            ]
          }
        }
        startupProbe = {
          exec = {
            command = [
              "redis-cli",
              "-s",
              local.valkey_socket_file,
              "ping",
            ]
          }
        }
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.searxng
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
            containerPort = local.extra_configs.SEARXNG_PORT
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.extra_configs.SEARXNG_SETTINGS_PATH
            subPath   = basename(local.extra_configs.SEARXNG_SETTINGS_PATH)
          },
          {
            name      = "socket"
            mountPath = dirname(local.valkey_socket_file)
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.extra_configs.SEARXNG_PORT
            path = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 4
        }
        readinessProbe = {
          httpGet = {
            port = local.extra_configs.SEARXNG_PORT
            path = "/healthz"
          }
          timeoutSeconds = 4
        }
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "socket"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}