locals {
  module_ignition_snippets = [
    for f in fileset(".", "${path.module}/ignition/*.yaml") :
    templatefile(f, {
      hardware_interface_name = var.hardware_interface_name
      ssid                    = var.ssid
      bssid                   = replace(var.bssid, "-", ":")
      nas_identifier          = replace(var.bssid, "/[-:]/", "")
      passphrase              = var.passphrase
      ht_capab = [
        "LDPC",
        "HT40-",
        "HT40+",
        "SHORT-GI-20",
        "SHORT-GI-40",
        "TX-STBC",
        "RX-STBC1",
        "DSSS_CCK-40",
      ]
      hostapd_container_image = var.hostapd_container_image
      mobility_domain         = var.hostapd_mobility_domain
      encryption_key          = var.hostapd_encryption_key
      roaming_members = [
        for member in var.hostapd_roaming_members :
        merge(member, {
          bssid          = replace(member.bssid, "-", ":")
          nas_identifier = replace(member.bssid, "/[-:]/", "")
        })
      ]
    })
  ]
}