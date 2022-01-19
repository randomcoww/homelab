locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      hardware_interface_name  = var.hardware_interface_name
      vlan_interface_name      = var.vlan_interface_name
      br_interface_name        = var.br_interface_name
      roaming_mobility_domain  = var.roaming_mobility_domain
      ssid                     = var.ssid
      passphrase               = var.passphrase
      nasid                    = var.nasid
      hostapd_container_image  = var.hostapd_container_image
      static_pod_manifest_path = var.static_pod_manifest_path
    })
  ]
}