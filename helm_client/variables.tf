variable "aws_region" {
  type = string
}

# User override (local.preprocess.users)
variable "users" {
  type    = any
  default = {}
}

variable "letsencrypt" {
  type = object({
    email = string
  })
}

variable "cloudflare" {
  type = object({
    email      = string
    account_id = string
    api_key    = string
  })
}

variable "wireguard_client" {
  type = object({
    Interface = map(string)
    Peer      = map(string)
  })
}

variable "hostapd" {
  type = map(string)
}