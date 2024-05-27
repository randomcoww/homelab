locals {
  jfs_db_path            = "/var/lib/jfs/${var.name}.db"
  transmission_home_path = "/var/lib/transmission"
  transmission_conf_path = "/tmp/settings.json"
  torrent_done_script    = "/torrent-done.sh"
  cache_mount_path       = "/incomplete"
  blocklist_update_job_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.transmission
        command = [
          "transmission-remote",
          "${var.name}.${var.namespace}:${var.ports.transmission}",
          "--blocklist-update",
        ]
      },
    ]
    dnsConfig = {
      options = [
        {
          name  = "ndots"
          value = "2"
        },
      ]
    }
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.transmission)[1]
  manifests = {
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/post-job.yaml" = yamlencode({
      apiVersion = "batch/v1"
      kind       = "Job"
      metadata = {
        name = "${var.name}-update-blocklist"
        labels = {
          app     = var.name
          release = var.release
        }
        annotations = {
          "helm.sh/hook"               = "post-install,post-upgrade"
          "helm.sh/hook-delete-policy" = "hook-succeeded,before-hook-creation"
        }
      }
      spec = {
        template = {
          metadata = {
            labels = {
              app = var.name
            }
          }
          spec = merge(local.blocklist_update_job_spec, {
            restartPolicy = "OnFailure"
          })
        }
      }
    })
    "templates/cronjob.yaml" = yamlencode({
      apiVersion = "batch/v1"
      kind       = "CronJob"
      metadata = {
        name = "${var.name}-update-blocklist"
        labels = {
          app     = var.name
          release = var.release
        }
      }
      spec = {
        schedule = var.blocklist_update_schedule
        jobTemplate = {
          spec = {
            ttlSecondsAfterFinished = 21600
            template = {
              metadata = {
                labels = {
                  app = var.name
                }
              }
              spec = merge(local.blocklist_update_job_spec, {
                restartPolicy = "Never"
              })
            }
          }
        }
      }
    })
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    "wg0.conf"        = var.wireguard_config
    "torrent-done.sh" = var.torrent_done_script
    "settings.json" = jsonencode(merge(var.transmission_settings, {
      bind-address-ipv4            = "0.0.0.0"
      script-torrent-done-filename = local.torrent_done_script
      rpc-bind-address             = "0.0.0.0"
      rpc-port                     = var.ports.transmission
      rpc-enabled                  = true
    }))
    "litestream.yml" = yamlencode({
      dbs = [
        {
          path = local.jfs_db_path
          replicas = [
            {
              type              = "s3"
              bucket            = var.jfs_minio_bucket
              path              = basename(local.jfs_db_path)
              endpoint          = "http://${var.jfs_minio_endpoint}"
              access-key-id     = var.jfs_minio_access_key_id
              secret-access-key = var.jfs_minio_secret_access_key
            },
          ]
        },
      ]
    })
  }
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "transmission"
        port       = var.ports.transmission
        protocol   = "TCP"
        targetPort = var.ports.transmission
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = module.service.name
          port    = var.ports.transmission
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    initContainers = [
      {
        name  = "${var.name}-wg"
        image = var.images.wireguard
        args = [
          "up",
          "wg0",
        ]
        securityContext = {
          privileged = true
        }
        volumeMounts = [
          {
            name      = "config"
            mountPath = "/etc/wireguard/wg0.conf"
            subPath   = "wg0.conf"
          },
        ]
      },
      {
        name  = "${var.name}-init"
        image = var.images.litestream
        args = [
          "restore",
          "-if-replica-exists",
          "-config",
          "/etc/litestream.yml",
          local.jfs_db_path,
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "config"
            mountPath = "/etc/litestream.yml"
            subPath   = "litestream.yml"
          },
        ]
      }
    ]
    containers = [
      {
        name  = var.name
        image = var.images.transmission
        env = [
          {
            name  = "TR_RPC_PORT"
            value = tostring(var.ports.transmission)
          },
          {
            name  = "JFS_RESOURCE_NAME"
            value = var.name
          },
          {
            name  = "JFS_MINIO_BUCKET"
            value = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_bucket}"
          },
          {
            name  = "JFS_DB_PATH"
            value = local.jfs_db_path
          },
          {
            name  = "TRANSMISSION_HOME_PATH"
            value = local.transmission_home_path
          },
          {
            name  = "TRANSMISSION_CONF_PATH"
            value = local.transmission_conf_path
          },
          {
            name  = "TRANSMISSION_PORT"
            value = tostring(var.ports.transmission)
          },
          {
            name  = "CACHE_MOUNT_PATH"
            value = local.cache_mount_path
          },
          {
            name  = "ACCESS_KEY_ID"
            value = var.jfs_minio_access_key_id
          },
          {
            name  = "SECRET_ACCESS_KEY"
            value = var.jfs_minio_secret_access_key
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = local.transmission_conf_path
            subPath   = "settings.json"
          },
          {
            name      = "config"
            mountPath = local.torrent_done_script
            subPath   = "torrent-done.sh"
          },
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
        ]
        ports = [
          {
            containerPort = var.ports.transmission
          },
        ]
        resources = merge({
          limits = {
            "github.com/fuse" = 1
          }
        }, var.resources)
        securityContext = {
          capabilities = {
            add = [
              "SYS_ADMIN",
            ]
          }
        }
      },
      {
        name  = "${var.name}-backup"
        image = var.images.litestream
        args = [
          "replicate",
          "-config",
          "/etc/litestream.yml",
        ]
        volumeMounts = [
          {
            name      = "jfs-data"
            mountPath = dirname(local.jfs_db_path)
          },
          {
            name      = "config"
            mountPath = "/etc/litestream.yml"
            subPath   = "litestream.yml"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
        }
      },
      {
        name = "jfs-data"
        emptyDir = {
          medium = "Memory"
        }
      },
    ]
  }
}