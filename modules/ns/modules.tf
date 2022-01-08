module "template-vm_network" {
  source                 = "../../modules/vm_network"
  networks               = var.networks
  host_netnum            = var.netnums.host
  interfaces             = var.interfaces
  interface_device_order = var.interface_device_order
}

module "template-ssh_server" {
  source     = "../../modules/ssh_server"
  key_id     = var.hostname
  user_names = [var.user.name]
  valid_principals = compact(concat([var.hostname, "127.0.0.1"], flatten([
    for interface in values(local.interfaces) :
    try(cidrhost(interface.prefix, var.netnums.host), null)
  ])))
  ssh_ca = var.ssh_ca
}

locals {
  interfaces = module.template-vm_network.interfaces
  module_ignition_snippets = concat(
    module.template-vm_network.ignition_snippets,
    module.template-ssh_server.ignition_snippets,
  )
}