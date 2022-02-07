variable "roaming_interfaces" {
  type = map(object({
    interface_name = string
    mac            = string
  }))
}

variable "ssid" {
  type = string
}

variable "passphrase" {
  type = string
}