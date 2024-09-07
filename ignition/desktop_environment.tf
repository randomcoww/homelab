module "desktop-environment" {
  for_each = local.members.desktop-environment
  source   = "./modules/desktop_environment"

  ignition_version = local.ignition_version
}

module "sunshine-hacks" {
  for_each = local.members.sunshine-hacks
  source   = "./modules/sunshine_hacks"

  ignition_version        = local.ignition_version
  external_interface_name = each.value.networks.wan.interface
}