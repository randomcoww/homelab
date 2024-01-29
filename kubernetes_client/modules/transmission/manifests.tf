locals {
  transmission_home_path = "/var/lib/transmission"
  torrent_done_script    = "/torrent-done.sh"
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
  }
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.transmission)[1]
  manifests = {
    "templates/service.yaml"    = module.service.manifest
    "templates/ingress.yaml"    = module.ingress.manifest
    "templates/secret.yaml"     = module.secret.manifest
    "templates/deployment.yaml" = module.deployment.manifest
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
          service = var.name
          port    = var.ports.transmission
          path    = "/"
        }
      ]
    },
  ]
}

module "deployment" {
  source   = "../deployment"
  name     = var.name
  app      = var.name
  release  = var.release
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
          mkdir -p ${local.transmission_home_path}
          cp \
            /tmp/settings.json \
            ${local.transmission_home_path}

          exec transmission-daemon \
            --foreground \
            --rpc-bind-address 0.0.0.0 \
            --port ${var.ports.transmission} \
            --no-portmap \
            --config-dir ${local.transmission_home_path}
          EOF
        ]
        env = [
          {
            name  = "TR_RPC_PORT"
            value = tostring(var.ports.transmission)
          },
        ]
        volumeMounts = [
          {
            name      = "config"
            mountPath = "/tmp/settings.json"
            subPath   = "settings.json"
          },
          {
            name      = "config"
            mountPath = local.torrent_done_script
            subPath   = "torrent-done.sh"
          },
        ]
        ports = [
          {
            containerPort = var.ports.transmission
          },
        ]
        resources = var.resources
      },
    ]
    volumes = [
      {
        name = "config"
        secret = {
          secretName  = var.name
          defaultMode = 493
        }
      },
    ]
  }
}