locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      udev_steam_input = data.http.udev-60-steam-input.response_body
      udev_steam_vr    = data.http.udev-60-steam-vr.response_body
    })
  ]
}