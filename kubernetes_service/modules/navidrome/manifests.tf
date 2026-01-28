locals {
  navidrome_config = merge(var.extra_configs, {
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
  db_file = "${local.navidrome_config["ND_DATAFOLDER"]}/navidrome.db" # db name not configurable
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = var.release
  manifests = merge({
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    }, {
    for i, m in module.litestream-overlay.additional_manifests :
    "templates/litestream-${i}.yaml" => m
  })
}

module "service" {
  source  = "../../../modules/service"
  name    = var.name
  app     = var.name
  release = var.release
  annotations = {
    "prometheus.io/scrape" = "true"
    "prometheus.io/port"   = tostring(local.navidrome_config["ND_PORT"])
    "prometheus.io/path"   = local.navidrome_config["ND_PROMETHEUS_METRICSPATH"]
  }
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = var.name
        port       = local.navidrome_config["ND_PORT"]
        protocol   = "TCP"
        targetPort = local.navidrome_config["ND_PORT"]
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
          port    = local.navidrome_config["ND_PORT"]
          path    = "/"
        },
      ]
    },
  ]
}

module "litestream-overlay" {
  source = "../litestream_overlay"

  name    = var.name
  app     = var.name
  release = var.release
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
        }
      },
    ]
  }
  sqlite_path         = local.db_file
  minio_access_secret = var.minio_access_secret

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
        image = var.images.navidrome
        ports = [
          {
            containerPort = local.navidrome_config["ND_PORT"]
          },
        ]
        env = [
          for k, v in local.navidrome_config :
          {
            name  = tostring(k)
            value = tostring(v)
          }
        ]
        volumeMounts = [
          {
            name      = "cache"
            mountPath = local.navidrome_config["ND_CACHEFOLDER"]
          },
        ]
        # TODO: add health checks
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
    ]
  }
}

module "mountpoint-s3-overlay" {
  source = "../mountpoint_s3_overlay"

  name        = var.name
  app         = var.name
  release     = var.release
  mount_path  = local.navidrome_config["ND_MUSICFOLDER"]
  s3_endpoint = var.minio_endpoint
  s3_bucket   = var.minio_data_bucket
  s3_prefix   = ""
  s3_mount_extra_args = [
    "--read-only",
    # "--cache /var/cache", # cache to disk
    "--cache /var/tmp",      # cache to memory
    "--max-cache-size 1024", # 1Gi
  ]
  s3_access_secret = var.minio_access_secret
  images = {
    mountpoint = var.images.mountpoint
  }

  template_spec = module.litestream-overlay.template_spec
}

module "statefulset" {
  source = "../../../modules/statefulset"

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = var.replicas
  annotations = {
    for i, m in module.litestream-overlay.additional_manifests :
    "checksum/litestream-${i}" => sha256(m)
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
  template_spec = module.mountpoint-s3-overlay.template_spec
}