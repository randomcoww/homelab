locals {
  base_path   = "/tmp/renovate"
  config_path = "/opt/renovate/config.json"
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.renovate_bot)[1]
  manifests = {
    "templates/secret.yaml"    = module.secret.manifest
    "templates/configmap.yaml" = module.configmap.manifest
    "templates/cronjob.yaml" = yamlencode({
      apiVersion = "batch/v1"
      kind       = "CronJob"
      metadata = {
        name = var.name
        labels = {
          app     = var.name
          release = var.release
        }
      }
      spec = {
        schedule          = var.cron
        suspend           = false
        concurrencyPolicy = "Forbid"
        jobTemplate = {
          spec = {
            ttlSecondsAfterFinished = 7200
            template = {
              metadata = {
                labels = {
                  app = var.name
                }
              }
              spec = {
                restartPolicy = "Never"
                containers = [
                  {
                    name  = var.name
                    image = var.images.renovate_bot
                    env = [
                      {
                        name  = "RENOVATE_BASE_DIR"
                        value = local.base_path
                      },
                      {
                        name  = "RENOVATE_CONFIG_FILE"
                        value = local.config_path
                      },
                    ]
                    envFrom = [
                      {
                        secretRef = {
                          name = module.secret.name
                        }
                      },
                    ]
                    volumeMounts = [
                      {
                        name      = "config"
                        mountPath = dirname(local.config_path)
                      },
                    ]
                  },
                ]
                volumes = [
                  {
                    name = "config"
                    configMap = {
                      name = module.configmap.name
                    }
                  }
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
          }
        }
      }
    })
  }
}

module "configmap" {
  source  = "../../../modules/configmap"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    basename(local.config_path) = jsonencode(var.renovate_config)
  }
}

module "secret" {
  source  = "../../../modules/secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = {
    for _, env in var.extra_envs :
    env.name => tostring(env.value)
  }
}