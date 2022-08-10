variable "hostapd" {
  type = object({
    ssid       = string
    passphrase = string
  })
}

variable "letsencrypt_email" {
  type = string
}

variable "authelia_users" {
  type    = any
  default = {}
}

variable "wireguard_client" {
  type = object({
    Interface = map(string)
    Peer      = map(string)
  })
}