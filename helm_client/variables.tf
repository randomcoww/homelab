variable "wifi" {
  type = object({
    ssid       = string
    passphrase = string
  })
}

variable "letsencrypt_email" {
  type = string
}