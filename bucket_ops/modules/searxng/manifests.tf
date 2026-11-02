
locals {
  envs = {
    SEARXNG_SETTINGS_PATH   = "/etc/searxng/settings.yml"
    SEARXNG_LIMITER         = false
    SEARXNG_PUBLIC_INSTANCE = false
    SEARXNG_IMAGE_PROXY     = false
    SEARXNG_BIND_ADDRESS    = "0.0.0.0"
    SEARXNG_PORT            = 8080
    SEARXNG_SECRET          = random_password.searxng-secret.result
  }

  mcp_envs = merge(var.extra_mcp_envs, {
    SEARXNG_URL                = "http://127.0.0.1:${local.envs.SEARXNG_PORT}"
    SEARXNG_DEFAULT_SAFESEARCH = 0
    MCP_HTTP_HOST              = "0.0.0.0"
  })
}

resource "random_password" "searxng-secret" {
  length  = 30
  special = false
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    for k, v in local.envs :
    tostring(k) => tostring(v)
    }, {
    for k, v in local.mcp_envs :
    tostring(k) => tostring(v)
    }, {
    basename(local.envs.SEARXNG_SETTINGS_PATH) = yamlencode(var.searxng_settings)
  })
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  labels = {
    agentgateway-mcp = var.name
  }
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name        = "searxng"
        port        = local.mcp_envs.MCP_HTTP_PORT
        protocol    = "TCP"
        targetPort  = local.mcp_envs.MCP_HTTP_PORT
        appProtocol = "agentgateway.dev/mcp"
      },
    ]
  }
}

module "deployment" {
  source    = "../../../modules/deployment"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "128Mi"
      }
      requests = {
        memory = "256Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = "${var.images.searxng.repository}:${var.images.searxng.tag}"
        env = [
          for k, v in local.envs :
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
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.envs.SEARXNG_SETTINGS_PATH
            subPath   = basename(local.envs.SEARXNG_SETTINGS_PATH)
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.envs.SEARXNG_PORT
            path = "/healthz"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 4
        }
        readinessProbe = {
          httpGet = {
            port = local.envs.SEARXNG_PORT
            path = "/healthz"
          }
          timeoutSeconds = 4
        }
      },
      {
        name  = "${var.name}-mcp"
        image = "${var.images.searxng-mcp.repository}:${var.images.searxng-mcp.tag}"
        env = [
          for k, v in local.mcp_envs :
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
            containerPort = local.mcp_envs.MCP_HTTP_PORT
          },
        ]
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