locals {
  home_path  = "/var/lib/transmission"
  mount_path = "${local.home_path}/mnt"
  transmission_settings = merge({
    script-torrent-done-filename = "/torrent-done.sh"
    rpc-port                     = 9091
    }, var.transmission_settings, {
    rpc-enabled            = true
    rpc-bind-address       = "0.0.0.0"
    bind-address-ipv4      = "0.0.0.0"
    download-dir           = "${local.mount_path}/downloads"
    incomplete-dir-enabled = false
    rename-partial-files   = false
    trash-can-enabled      = false
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
        },
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
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    volumeClaimTemplates = [
      {
        metadata = {
          name = "transmission-resume"
        }
        spec = {
          accessModes = [
            "ReadWriteOnce",
          ]
          resources = {
            requests = {
              storage = "40Gi"
            }
          }
          storageClassName = "local-path"
        }
      },
    ]
  }
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.transmission
        command = [
          "sh",
          "-c",
          <<-EOF
          set -e

          mkdir -p \
            ${local.mount_path}/resume \
            ${local.mount_path}/torrents \
            $HOME
          ln -sf \
            ${local.mount_path}/resume \
            ${local.mount_path}/torrents \
            $HOME
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
            value = local.home_path
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
          },
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
          {
            name      = "transmission-resume"
            mountPath = local.mount_path
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