output "members" {
  value = {
    for host_key, member in var.members :
    host_key => merge(member, {
      bssid           = replace(member.mac, "-", ":")
      nas_identifier  = replace(member.mac, "/[-:]/", "")
      mobility_domain = random_id.hostapd-mobility-domain.hex
      encryption_key  = random_id.hostapd-encryption-key.hex
    })
  }
}