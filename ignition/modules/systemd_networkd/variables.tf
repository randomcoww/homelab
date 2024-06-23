variable "ignition_version" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "tap_interfaces" {
  type    = any
  default = {}
}

variable "bridge_interfaces" {
  type    = any
  default = {}
}

variable "physical_interfaces" {
  type    = any
  default = {}
}

variable "wlan_interfaces" {
  type    = any
  default = {}
}