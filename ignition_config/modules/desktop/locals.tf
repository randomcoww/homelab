locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      ssh_ca_authorized_key = var.ssh_ca_public_key_openssh
      udev_steam_input      = data.http.udev-60-steam-input.response_body
      udev_steam_vr         = data.http.udev-60-steam-vr.response_body
      wlan_interface        = var.wlan_interface
      monitors_config       = data.local_file.monitors.content
      sunshine_config = {
        min_threads             = 1
        origin_web_ui_allowed   = "pc"
        origin_pin_allowed      = "pc"
        upnp                    = "off"
        key_rightalt_to_key_win = "enabled"
        output_name             = 0
      }
    })
  ]
}