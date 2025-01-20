module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.coreos_assembler)[1]
  manifests = {
    "templates/deployment.yaml" = module.deployment.manifest
  }
}

# https://coreos.github.io/coreos-assembler/working/

module "deployment" {
  source   = "../../../modules/deployment"
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
        env = [
          for _, e in var.extra_envs :
          {
            name  = e.name
            value = tostring(e.value)
          }
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