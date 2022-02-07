output "roaming_credentials" {
  value = {
    mobility_domain = random_id.hostapd-mobility-domain.hex
    encryption_key  = random_id.hostapd-encryption-key.hex
  }
}