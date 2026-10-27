locals {
  envs = merge(var.extra_envs, {
    STUMP_CONFIG_DIR              = "/stump/config"
    STUMP_PORT                    = 8000
    STUMP_OIDC_ENABLED            = true
    STUMP_OIDC_ALLOW_REGISTRATION = true
    STUMP_OIDC_DISABLE_LOCAL_AUTH = true
    ENABLE_SWAGGER_UI             = false
    ENABLE_KOREADER_SYNC          = false
    ENABLE_OPDS_PROGRESSION       = false
    STUMP_ENABLE_UPLOAD           = false
    STUMP_PRETTY_LOGS             = false
    STUMP_TRUST_PROXY_HEADERS     = true
    STUMP_VERBOSITY               = 0 # disable internal log file
    STUMP_ALLOWED_ORIGINS         = "https://${var.ingress_hostname}"
    STUMP_DB_NAME                 = "stump"
    STUMP_DB_USER                 = "stump"
  })
  data_path       = "/data"                                     # library mount path
  thumbnails_path = "${local.envs.STUMP_CONFIG_DIR}/thumbnails" # non-configurable
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for k, v in local.envs :
    tostring(k) => tostring(v)
  }
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  spec = {
    type      = "ClusterIP"
    clusterIP = "None"
    ports = [
      {
        name       = var.name
        port       = local.envs.STUMP_PORT
        protocol   = "TCP"
        targetPort = local.envs.STUMP_PORT
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
            port = local.envs.STUMP_PORT
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
        memory = "1Gi"
      }
      limits = {
        memory = "3Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = "${var.images.stump.repository}:${var.images.stump.tag}"
        ports = [
          {
            containerPort = local.envs.STUMP_PORT
          },
        ]
        envFrom = [
          {
            secretRef = {
              name = module.secret.name
            }
          },
        ]
        env = [
          {
            name = "STUMP_DB_HOST"
            valueFrom = {
              secretKeyRef = {
                name = "${var.name}-pg-app"
                key  = "host"
              }
            }
          },
          {
            name = "STUMP_DB_PORT"
            valueFrom = {
              secretKeyRef = {
                name = "${var.name}-pg-app"
                key  = "port"
              }
            }
          },
          {
            name = "STUMP_DB_PASSWORD"
            valueFrom = {
              secretKeyRef = {
                name = "${var.name}-pg-app"
                key  = "password"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "data"
            mountPath = local.data_path
          },
          {
            name      = "thumbnails"
            mountPath = local.thumbnails_path
            subPath   = "mount"
          },
        ]
        livenessProbe = {
          httpGet = {
            port = local.envs.STUMP_PORT
            path = "/api/v2/ping"
          }
          timeoutSeconds   = 4
          failureThreshold = 6
        }
        readinessProbe = {
          httpGet = {
            port = local.envs.STUMP_PORT
            path = "/api/v2/ping"
          }
          timeoutSeconds = 4
        }
      },
    ]
    volumes = [
      {
        name = "data"
        persistentVolumeClaim = {
          claimName = "${var.name}-${var.minio_data_bucket}"
        }
      },
      {
        name = "thumbnails"
        persistentVolumeClaim = {
          claimName = "${var.name}-${var.minio_bucket}"
        }
      },
    ]
  }
}