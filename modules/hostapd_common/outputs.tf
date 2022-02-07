output "template_params" {
  value = {
    for host_key, member in local.roaming_members :
    host_key => {
      ssid            = var.ssid
      passphrase      = var.passphrase
      mobility_domain = random_id.hostapd-mobility-domain.hex
      encryption_key  = random_id.hostapd-encryption-key.hex

      interface_name  = member.interface_name
      bssid           = member.bssid
      nas_identifier  = member.nas_identifier
      roaming_members = values(local.roaming_members)
    }
  }
}