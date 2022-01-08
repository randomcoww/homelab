module "template-vm_network" {
  source                 = "../../modules/vm_network"
  networks               = var.networks
  host_netnum            = var.netnums.host
  interfaces             = var.interfaces
  interface_device_order = var.interface_device_order
}

locals {
  interfaces = module.template-vm_network.interfaces
  module_ignition_snippets = concat(
    module.template-vm_network.ignition_snippets,
  )
}