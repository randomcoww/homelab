
locals {
  extra_configs = merge(var.extra_configs, {
    SEARXNG_SETTINGS_PATH   = "/etc/searxng/settings.yml"
    SEARXNG_LIMITER         = false
    SEARXNG_PUBLIC_INSTANCE = false
    SEARXNG_IMAGE_PROXY     = false
    SEARXNG_BIND_ADDRESS    = "0.0.0.0"
    SEARXNG_PORT            = 8080
    SEARXNG_SECRET          = random_password.searxng-secret.result
  })

  manifests = [
    module.deployment.manifest,
    module.secret.manifest,
    module.service.manifest,
    module.httproute.manifest,
  ]
}

resource "random_password" "searxng-secret" {
  length  = 30
  special = false
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

module "httproute" {
  source  = "../../../modules/httproute"
  name    = var.name
  app     = var.name
  release = var.release
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
            port = local.extra_configs.SEARXNG_PORT
          },
        ]
      },
    ]
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
    resources = {
      requests = {
        memory = "256Mi"
      }
      limits = {
        memory = "512Mi"
      }
    }
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
    ]
  }
}