
locals {
  valkey_socket_path = "/var/run/valkey/socket.sock"
  extra_configs = merge(var.extra_configs, {
    SEARXNG_SETTINGS_PATH   = "/etc/searxng/settings.yml"
    SEARXNG_LIMITER         = false
    SEARXNG_PUBLIC_INSTANCE = false
    SEARXNG_IMAGE_PROXY     = false
    SEARXNG_BIND_ADDRESS    = "0.0.0.0"
    SEARXNG_PORT            = var.ports.searxng
    SEARXNG_SECRET          = random_password.searxng-secret.result
    SEARXNG_VALKEY_URL      = "unix://${local.valkey_socket_path}?db=0"
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
  app_version = split(":", var.images.searxng)[1]
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/service.yaml"    = module.service.manifest
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
        port       = var.ports.searxng
        protocol   = "TCP"
        targetPort = var.ports.searxng
      },
    ]
    sessionAffinity = "ClientIP"
    sessionAffinityConfig = {
      clientIP = {
        timeoutSeconds = 10800
      }
    }
  }
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
    initContainers = [
      {
        name          = "${var.name}-valkey"
        image         = var.images.valkey
        restartPolicy = "Always"
        args = [
          "--unixsocket",
          "${local.valkey_socket_path}",
          "--port",
          "0",
        ]
        volumeMounts = [
          {
            name      = "socket"
            mountPath = dirname(local.valkey_socket_path)
          },
        ]
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
            containerPort = var.ports.searxng
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
            mountPath = dirname(local.valkey_socket_path)
          },
        ]
        readinessProbe = {
          httpGet = {
            port = var.ports.searxng
            path = "/healthz"
          }
        }
        livenessProbe = {
          httpGet = {
            port = var.ports.searxng
            path = "/healthz"
          }
        }
        startupProbe = {
          httpGet = {
            port = var.ports.searxng
            path = "/healthz"
          }
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
        name     = "socket"
        emptyDir = {}
      },
    ]
  }
}