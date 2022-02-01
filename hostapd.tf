# Hostapd #
resource "random_id" "hostapd_encryption_key" {
  byte_length = 64
}

resource "random_id" "hostapd_mobility_domain" {
  byte_length = 2
}