# Hostapd #
resource "random_id" "hostapd-encryption-key" {
  byte_length = 64
}

resource "random_id" "hostapd-mobility-domain" {
  byte_length = 2
}