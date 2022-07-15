variable "wifi" {
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