# https://coreos.github.io/coreos-assembler/working/

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.coreos_assembler)[1]
  manifests = {
    # "templates/statefulset.yaml" = module.statefulset.manifest
    "templates/secret.yaml" = module.secret.manifest
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
        schedule          = "0 0 * * 0"
        suspend           = true
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
              spec = {
                restartPolicy = "Never"
                containers = [
                  {
                    name    = var.name
                    image   = var.images.coreos_assembler
                    command = var.command
                    envFrom = [
                      {
                        secretRef = {
                          name = module.secret.name
                        }
                      },
                    ]
                    resources = {
                      requests = {
                        memory                    = "4Gi"
                        "devices.kubevirt.io/kvm" = "1"
                      }
                      limits = {
                        "devices.kubevirt.io/kvm" = "1"
                      }
                    }
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
          }
        }
      }
    })
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

# disabled: environment for manual build

module "statefulset" {
  source   = "../../../modules/statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  template_spec = {
    containers = [
      {
        name  = var.name
        image = var.images.coreos_assembler
        command = [
          "sleep",
          "infinity",
        ]
        envFrom = [
          {
            secretRef = {
              name = module.secret.name
            }
          },
        ]
        resources = {
          requests = {
            memory                    = "4Gi"
            "devices.kubevirt.io/kvm" = "1"
          }
          limits = {
            "devices.kubevirt.io/kvm" = "1"
          }
        }
      },
    ]
  }
}