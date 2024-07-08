locals {
  transmission_home_path = "/var/lib/transmission/mnt"
  transmission_settings = merge({
    script-torrent-done-filename = "/torrent-done.sh"
    rpc-port                     = 9091
    }, var.transmission_settings, {
    rpc-enabled       = true
    rpc-bind-address  = "0.0.0.0"
    bind-address-ipv4 = "0.0.0.0"
  })
  blocklist_update_job_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.transmission
        command = [
          "transmission-remote",
          "${var.name}.${var.namespace}:${local.transmission_settings.rpc-port}",
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
  jfs_metadata_path = "/var/lib/jfs/${var.name}.db"
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
    "templates/statefulset.yaml" = module.statefulset-jfs.statefulset
    "templates/secret-jfs.yaml"  = module.statefulset-jfs.secret
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
        schedule          = var.blocklist_update_schedule
        concurrencyPolicy = "Forbid"
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
    "wg0.conf"                                                         = var.wireguard_config
    basename(local.transmission_settings.script-torrent-done-filename) = var.torrent_done_script
    "settings.json"                                                    = jsonencode(local.transmission_settings)
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
        port       = local.transmission_settings.rpc-port
        protocol   = "TCP"
        targetPort = local.transmission_settings.rpc-port
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
          port    = local.transmission_settings.rpc-port
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset-jfs" {
  source = "../statefulset_jfs"
  ## jfs settings
  jfs_metadata_endpoint       = var.jfs_metadata_endpoint
  jfs_metadata_ca             = var.jfs_metadata_ca
  jfs_image                   = var.images.jfs
  jfs_mount_path              = local.transmission_home_path
  jfs_minio_resource          = "http://${var.jfs_minio_endpoint}/${var.jfs_minio_resource}"
  jfs_minio_access_key_id     = var.jfs_minio_access_key_id
  jfs_minio_secret_access_key = var.jfs_minio_secret_access_key
  ##

  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
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
            name      = "secret"
            mountPath = "/etc/wireguard/wg0.conf"
            subPath   = "wg0.conf"
          },
        ]
      },
    ]
    containers = [
      {
        name  = var.name
        image = var.images.transmission
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mountpoint $HOME
          echo -e "$TRANSMISSION_CONFIG" > $HOME/settings.json

          exec transmission-daemon \
            --foreground \
            --config-dir $HOME
          EOF
        ]
        env = concat([
          # default transmission paths go under $HOME
          {
            name  = "HOME"
            value = local.transmission_home_path
          },
          {
            name  = "TR_RPC_PORT"
            value = tostring(local.transmission_settings.rpc-port)
          },
          {
            name = "TRANSMISSION_CONFIG"
            valueFrom = {
              secretKeyRef = {
                name = module.secret.name
                key  = "settings.json"
              }
            }
          }
          ], [
          for _, e in var.transmission_extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
        ])
        volumeMounts = [
          {
            name      = "secret"
            mountPath = local.transmission_settings.script-torrent-done-filename
            subPath   = basename(local.transmission_settings.script-torrent-done-filename)
          },
        ]
        ports = [
          {
            containerPort = local.transmission_settings.rpc-port
          },
        ]
        readinessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.transmission_settings.rpc-port
            path   = "/"
          }
        }
        livenessProbe = {
          httpGet = {
            scheme = "HTTP"
            port   = local.transmission_settings.rpc-port
            path   = "/"
          }
        }
      },
    ]
    volumes = [
      {
        name = "secret"
        secret = {
          secretName  = module.secret.name
          defaultMode = 493
        }
      },
    ]
  }
}