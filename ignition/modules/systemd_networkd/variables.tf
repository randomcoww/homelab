variable "host_netnum" {
  type = number
}

variable "tap_interfaces" {
  type    = any
  default = {}
}

variable "virtual_interfaces" {
  type    = any
  default = {}
}

variable "bridge_interfaces" {
  type    = any
  default = {}
}

variable "hardware_interfaces" {
  type    = any
  default = {}
}

variable "wlan_interfaces" {
  type    = any
  default = {}
}