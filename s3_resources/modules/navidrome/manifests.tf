
locals {
  extra_envs = merge(var.extra_configs, {
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
  })
  db_file = "${local.extra_envs.ND_DATAFOLDER}/navidrome.db" # db name not configurable
}

module "service" {
  source    = "../../../modules/service"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(local.extra_envs.ND_PORT)
    "prometheus.io/path"   = local.extra_envs.ND_PROMETHEUS_METRICSPATH
  }
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = local.extra_envs.ND_PORT
        protocol   = "TCP"
        targetPort = local.extra_envs.ND_PORT
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
            port = local.extra_envs.ND_PORT
          },
        ]
        filters = [
          {
            type = "ExtensionRef"
            extensionRef = {
              group = "traefik.io"
              kind  = "Middleware"
              name  = var.name
            }
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
  mount_path       = dirname(local.db_file)
  s3_access_secret = module.minio-user-secret.name

  template_spec = {
    resources = {
      requests = {
        memory = "2Gi"
      }
    }
    containers = [
      {
        name  = var.name
        image = var.images.navidrome
        ports = [
          {
            containerPort = local.extra_envs.ND_PORT
          },
        ]
        env = [
          for k, v in local.extra_envs :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ]
        volumeMounts = [
          {
            name      = "cache"
            mountPath = local.extra_envs.ND_CACHEFOLDER
          },
          {
            name      = "data"
            mountPath = local.extra_envs.ND_MUSICFOLDER
          },
        ]
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.extra_envs.ND_PORT
            path   = "/"
          }
          initialDelaySeconds = 10
          timeoutSeconds      = 2
        }
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.extra_envs.ND_PORT
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
  annotations = merge({
    "checksum/minio-user-secret" = sha256(module.minio-user-secret.manifest)
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "checksum/litestream-${i}" => sha256(m)
  })
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
  template_spec = module.litestream-overlay.template_spec
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