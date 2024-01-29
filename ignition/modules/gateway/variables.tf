variable "container_images" {
  type = map(string)
}

variable "host_netnum" {
  type = number
}

variable "static_pod_manifest_path" {
  type = string
}

variable "accept_prefixes" {
  type = list(string)
}

variable "forward_prefixes" {
  type = list(string)
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

variable "sync_prefix" {
  type = string
}

variable "lan_interface_name" {
  type = string
}

variable "lan_prefix" {
  type = string
}

variable "lan_vip" {
  type = string
}

variable "dns_port" {
  type = number
}

variable "keepalived_config_path" {
  type    = string
  default = "/etc/keepalived/keepalived.conf.d"
}