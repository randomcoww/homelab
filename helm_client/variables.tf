variable "users" {
  type    = any
  default = {}
}

variable "letsencrypt" {
  type = object({
    email = string
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
    private_key = string
    public_key  = string
    address     = string
    endpoint    = string
  })
}

variable "tailscale" {
  type = object({
    auth_key = string
  })
}

variable "smtp" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
  })
}

variable "alpaca" {
  type = object({
    api_key_id     = string
    api_secret_key = string
    api_base_url   = string
  })
}