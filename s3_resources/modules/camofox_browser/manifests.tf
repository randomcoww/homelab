locals {
  extra_envs = merge(var.extra_configs, {
    CAMOFOX_PORT                       = 9377
    MAX_OLD_SPACE_SIZE                 = 2048
    MOZ_DISABLE_CONTENT_SANDBOX        = 1
    MOZ_DISABLE_SOCKET_PROCESS_SANDBOX = 1
    MOZ_DISABLE_RDD_SANDBOX            = 1
    MOZ_DISABLE_GMP_SANDBOX            = 1
    MOZ_DISABLE_UTILITY_SANDBOX        = 1
    MOZ_DISABLE_NPAPI_SANDBOX          = 1
  })
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    for k, v in local.extra_envs :
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
        port       = local.extra_envs.CAMOFOX_PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.CAMOFOX_PORT
      },
    ]
  }
}

module "httproute" {
  source    = "../../../modules/httproute"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
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
            port = local.extra_envs.CAMOFOX_PORT
          },
        ]
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
    }
    containers = [
      {
        name  = var.name
        image = var.images.camofox_browser
        env = [
          for k, v in local.extra_envs :
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
            port   = local.extra_envs.CAMOFOX_PORT
            path   = "/health"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.extra_envs.CAMOFOX_PORT
            path   = "/health"
          }
        }
      },
    ]
    volumes = [
      {
        name = "dev-shm"
        emptyDir = {
          medium    = "Memory"
          sizeLimit = "2Gi"
        }
      },
    ]
  }
}