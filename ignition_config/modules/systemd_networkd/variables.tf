variable "host_netnum" {
  type = number
}

variable "tap_interfaces" {
  type = map(map(string))
}

variable "bridge_interfaces" {
  type    = any
  default = {}
}

variable "hardware_interfaces" {
  type    = any
  default = {}
}

variable "networks" {
  type = any
}