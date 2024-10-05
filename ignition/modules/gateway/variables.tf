variable "ignition_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "conntrackd_ignore_prefixes" {
  type = list(string)
}

variable "wan_interface_name" {
  type = string
}

variable "sync_interface_name" {
  type = string
}

variable "lan_interface_name" {
  type = string
}

variable "sync_prefix" {
  type = string
}

variable "lan_gateway_ip" {
  type = string
}

variable "virtual_router_id" {
  type = number
}

variable "keepalived_path" {
  type = string
}