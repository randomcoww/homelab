variable "ignition_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "physical_interfaces" {
  type    = any
  default = {}
}

variable "bridge_interfaces" {
  type    = any
  default = {}
}

variable "vlan_interfaces" {
  type    = any
  default = {}
}

variable "networks" {
  type    = any
  default = {}
}

variable "wlan_networks" {
  type    = any
  default = {}
}

variable "mdns_domain" {
  type = string
}