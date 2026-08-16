variable "butane_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "wired_interfaces" {
  type    = any
  default = []
}

variable "wireless_interfaces" {
  type    = any
  default = []
}

variable "vlan_interfaces" {
  type    = any
  default = []
}

variable "bridge_interfaces" {
  type    = any
  default = []
}

variable "network_overrides" {
  type    = any
  default = []
}