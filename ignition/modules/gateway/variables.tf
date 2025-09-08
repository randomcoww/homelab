variable "butane_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "wan_interface_names" {
  type = list(string)
}

variable "bird_path" {
  type = string
}

variable "bird_cache_table_name" {
  type = string
}

variable "bgp_as" {
  type = number
}

variable "bgp_port" {
  type = number
}

variable "bgp_neighbor_netnums" {
  type = map(number)
}

variable "node_prefix" {
  type = string
}

variable "service_prefix" {
  type = string
}

variable "sync_prefix" {
  type = string
}

variable "sync_interface_name" {
  type = string
}

variable "conntrackd_ignore_ipv4" {
  type = list(string)
}

variable "keepalived_path" {
  type = string
}

variable "keepalived_interface_name" {
  type = string
}

variable "keepalived_vip" {
  type = string
}

variable "keepalived_router_id" {
  type = number
}