output "peers" {
  value = [
    for i, id in local.ids :
    {
      pod_name        = "${var.resource_name}-${i}"
      bssid           = join(":", regexall("\\w{2}", id))
      r1_key_holder   = id
      nas_identifier  = id
      mobility_domain = random_id.hostapd-mobility-domain.hex
      encryption_key  = random_id.hostapd-encryption-key.hex
    }
  ]
}