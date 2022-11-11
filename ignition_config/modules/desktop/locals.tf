locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      ssh_ca_authorized_key = var.ssh_ca_public_key_openssh
      udev_steam_input      = data.http.udev-60-steam-input.response_body
      udev_steam_vr         = data.http.udev-60-steam-vr.response_body
      wlan_interface        = var.wlan_interface
      sunshine_username     = var.sunshine_username
      sunshine_password     = var.sunshine_password
      sunshine_config = {
        min_threads             = 8
        origin_web_ui_allowed   = "lan"
        origin_pin_allowed      = "pc"
        key_rightalt_to_key_win = "enabled"
      }
    })
  ]
}