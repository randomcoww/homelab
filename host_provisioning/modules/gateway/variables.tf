variable "butane_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "vrrp_network_config" {
  type = any
}

variable "wan_network_config" {
  type = any
}

variable "bird_path" {
  type = string
}

variable "bird_cache_table_name" {
  type = string
}

variable "bird_slave_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
  default = {
    table_id       = 240
    table_priority = 32780
  }
}

variable "bgp_as" {
  type = number
}

variable "bgp_as_peer" {
  type = number
}

variable "bgp_as_members" {
  type    = number
  default = 65500
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

variable "keepalived_path" {
  type = string
}