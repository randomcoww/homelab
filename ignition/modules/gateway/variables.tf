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

variable "lan_prefix" {
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

variable "bird_path" {
  type = string
}

variable "bird_cache_table_name" {
  type = string
}

variable "bgp_prefix" {
  type = string
}

variable "bgp_as" {
  type = number
}

variable "bgp_port" {
  type = number
}

variable "bgp_internal_neighbor_netnums" {
  type = map(number)
}

variable "bgp_external_neighbor_netnums" {
  type = map(number)
}