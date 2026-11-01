locals {
  envs = merge(var.extra_envs, {
    MAX_OLD_SPACE_SIZE                 = 2048
    MOZ_DISABLE_CONTENT_SANDBOX        = 1
    MOZ_DISABLE_SOCKET_PROCESS_SANDBOX = 1
    MOZ_DISABLE_RDD_SANDBOX            = 1
    MOZ_DISABLE_GMP_SANDBOX            = 1
    MOZ_DISABLE_UTILITY_SANDBOX        = 1
    MOZ_DISABLE_NPAPI_SANDBOX          = 1
    CAMOFOX_PORT                       = 9377
    CAMOFOX_ACCESS_KEY                 = random_password.camofox-browser-auth-token.result
  })

  mcp_envs = merge(var.extra_mcp_envs, {
    CAMOFOX_URL       = "http://127.0.0.1:${local.envs.CAMOFOX_PORT}"
    CAMOFOX_HTTP_HOST = "0.0.0.0"
    CAMOFOX_API_KEY   = random_password.camofox-browser-auth-token.result
  })
}

resource "random_password" "camofox-browser-auth-token" {
  length           = 32
  override_special = "-_"
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
  })
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
        name       = var.name
        port       = local.mcp_envs.CAMOFOX_HTTP_PORT
        protocol   = "TCP"
        targetPort = local.mcp_envs.CAMOFOX_HTTP_PORT
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
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    resources = {
      requests = {
        memory = "2Gi"
      }
      limits = {
        memory = "4Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = "${var.images.camofox-browser.repository}:${var.images.camofox-browser.tag}"
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
            name      = "dev-shm"
            mountPath = "/dev/shm"
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.envs.CAMOFOX_PORT
            path   = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.envs.CAMOFOX_PORT
            path   = "/health"
          }
        }
      },
      {
        name  = "${var.name}-mcp"
        image = "${var.images.camofox-browser-mcp.repository}:${var.images.camofox-browser-mcp.tag}"
        args = [
          "node",
          "dist/http.js",
        ]
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
            containerPort = local.mcp_envs.CAMOFOX_HTTP_PORT
          },
        ]
      },
    ]
    volumes = [
      {
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "512Mi"
        }
      },
    ]
  }
}