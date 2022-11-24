# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

variable "hostapd" {
  type = map(string)
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