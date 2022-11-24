variable "hostapd" {
  type = object({
    ssid       = string
    passphrase = string
  })
}

# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

variable "letsencrypt_email" {
  type = string
}

variable "wireguard_client" {
  type = object({
    Interface = map(string)
    Peer      = map(string)
  })
}