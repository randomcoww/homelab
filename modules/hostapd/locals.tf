locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      hardware_interface_name  = var.hardware_interface_name
      source_interface_name    = var.source_interface_name
      bridge_interface_name    = var.bridge_interface_name
      bridge_interface_mtu     = var.bridge_interface_mtu
      ssid                     = var.ssid
      bssid                    = var.bssid
      nas_identifier           = replace(var.bssid, ":", "")
      passphrase               = var.passphrase
      hostapd_container_image  = var.hostapd_container_image
      static_pod_manifest_path = var.static_pod_manifest_path
      hostapd_mobility_domain  = var.hostapd_mobility_domain
      hostapd_encryption_key   = var.hostapd_encryption_key
      hostapd_roaming_members = [
        for member in var.hostapd_roaming_members :
        merge(member, {
          nas_identifier = replace(member.bssid, ":", "")
        })
      ]
    })
  ]
}