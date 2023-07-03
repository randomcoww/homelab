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
    api_token  = string
    account_id = string
  })
}

variable "hostapd" {
  type = map(string)
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

variable "tailscale" {
  type = object({
    auth_key = string
  })
}