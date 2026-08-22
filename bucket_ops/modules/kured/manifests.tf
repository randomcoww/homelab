locals {
  reboot_required_host_file = "/usr/local/bin/reboot-required.sh"
}

module "configmap" {
  source    = "../../../modules/configmap"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    basename(local.reboot_required_host_file) = var.reboot_required_script
  }
}
