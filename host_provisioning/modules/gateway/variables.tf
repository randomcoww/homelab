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

variable "master_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
  default = {
    table_id       = 250
    table_priority = 32770
  }
}

variable "slave_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
  default = {
    table_id       = 240
    table_priority = 32780
  }
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