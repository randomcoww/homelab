variable "wifi" {
  type = object({
    ssid       = string
    passphrase = string
  })
}