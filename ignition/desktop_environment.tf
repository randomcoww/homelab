module "desktop-environment" {
  for_each = local.members.desktop-environment
  source   = "./modules/desktop_environment"

  ignition_version = local.ignition_version
}

module "sunshine" {
  for_each = local.members.sunshine
  source   = "./modules/sunshine"

  ignition_version = local.ignition_version
  sunshine_config = {
    key_rightalt_to_key_win = "enabled"
    origin_web_ui_allowed   = "pc"
    encoder                 = "nvenc"
    output_name             = "1"
  }
  external_interface_name = each.value.networks.wan.interface
}