locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      hardware_interface_name  = var.hardware_interface_name
      source_interface_name    = var.source_interface_name
      br_interface_name        = var.br_interface_name
      ssid                     = var.ssid
      passphrase               = var.passphrase
      hostapd_container_image  = var.hostapd_container_image
      static_pod_manifest_path = var.static_pod_manifest_path
    })
  ]
}