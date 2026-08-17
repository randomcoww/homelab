
locals {
  envs = merge(var.extra_envs, {
    ND_MUSICFOLDER             = "/navidrome/library/mnt"
    ND_DATAFOLDER              = "/navidrome/data"
    ND_CACHEFOLDER             = "/navidrome/cache"
    ND_ADDRESS                 = "0.0.0.0"
    ND_PORT                    = 4533
    ND_AGENTS                  = ""
    ND_DEEZER_ENABLED          = false
    ND_ENABLEDOWNLOADS         = false
    ND_LASTFM_ENABLED          = false
    ND_LISTENBRAINZ_ENABLED    = false
    ND_PROMETHEUS_ENABLED      = true
    ND_ENABLEINSIGHTSCOLLECTOR = false
    ND_ENABLEFAVOURITES        = false
    ND_ENABLESTARRATING        = false
    ND_ENABLEUSEREDITING       = false
    ND_ENABLESCROBBLEHISTORY   = false
    ND_SEARCHFULLSTRING        = true
    ND_PROMETHEUS_METRICSPATH  = "/metrics"
    ND_SCANNER_PURGEMISSING    = "always"
    ND_SESSIONTIMEOUT          = "24h"
  })
  db_file = "${local.envs.ND_DATAFOLDER}/navidrome.db" # db name not configurable
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
        port       = local.envs.ND_PORT
        protocol   = "TCP"
        targetPort = local.envs.ND_PORT
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
        filters = [
          {
            type = "ExternalAuth"
            externalAuth = {
              protocol   = "HTTP"
              backendRef = var.auth_backend_ref
              http = {
                path = "/api/authz/ext-authz/"
                allowedHeaders = [
                  "accept",
                  "cookie",
                  "location",
                  "authorization",
                  "proxy-authorization",
                  "x-forwarded-proto",
                ]
                allowedResponseHeaders = [
                  "Remote-User",
                  "Remote-Email",
                  "Remote-Name",
                  "Remote-Groups",
                ]
              }
            }
          },
        ]
        backendRefs = [
          {
            name = module.service.name
            port = local.envs.ND_PORT
          },
        ]
      },
    ]
  }
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  images = {
    litestream = var.images.litestream
  }
  litestream_config = {
    dbs = [
      {
        path                = local.db_file
        monitor-interval    = "1s"
        checkpoint-interval = "60s"
        replica = {
          type          = "s3"
          endpoint      = var.minio_endpoint
          bucket        = var.minio_bucket
          path          = "$POD_NAME/litestream"
          sync-interval = "1s"
          part-size     = "50MB"
          concurrency   = 10
          auto-recover  = true
        }
      },
    ]
  }
  mount_path = dirname(local.db_file)
  s3_access_key_ref = {
    name = module.minio-user-secret.name
    key  = "AWS_ACCESS_KEY_ID"
  }
  s3_secret_key_ref = {
    name = module.minio-user-secret.name
    key  = "AWS_SECRET_ACCESS_KEY"
  }

  template_spec = {
    resources = {
      requests = {
        memory = "128Mi"
      }
      limits = {
        memory = "256Mi"
      }
    }
    containers = [
      {
        name  = var.name
        image = "${var.images.navidrome.repository}:${var.images.navidrome.tag}"
        ports = [
          {
            containerPort = local.envs.ND_PORT
          },
        ]
        env = [
          for k, v in local.envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ]
        volumeMounts = [
          {
            name      = "cache"
            mountPath = local.envs.ND_CACHEFOLDER
          },
          {
            name      = "data"
            mountPath = local.envs.ND_MUSICFOLDER
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.envs.ND_PORT
            path   = "/"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.envs.ND_PORT
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "${var.name}-litestream-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "cache"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "data"
        persistentVolumeClaim = {
          claimName = "${var.name}-${var.minio_data_bucket}"
        }
      },
    ]
  }
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
  }
  /* persistent path for sqlite
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
  */
  template_spec = merge(module.litestream-overlay.template_spec, {
    terminationGracePeriodSeconds = 60
  })
}

module "minio-user-secret" {
  source    = "../../../modules/secret"
  name      = "${var.name}-minio-user-secret"
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = merge({
    AWS_ACCESS_KEY_ID     = var.minio_user.id
    AWS_SECRET_ACCESS_KEY = var.minio_user.secret
  })
}