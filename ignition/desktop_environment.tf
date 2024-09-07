module "desktop-environment" {
  for_each = local.members.desktop-environment
  source   = "./modules/desktop_environment"

  ignition_version = local.ignition_version
}