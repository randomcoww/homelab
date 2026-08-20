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

variable "bird_cache_table" {
  type = object({
    name     = string
    table_id = number
  })
}

variable "bgp_as" {
  type = number
}

variable "bgp_as_peer" {
  type = number
}

variable "bgp_port" {
  type = number
}

variable "bgp_prefix" {
  type = string
}

variable "service_prefix" {
  type = string
}

variable "keepalived_path" {
  type = string
}