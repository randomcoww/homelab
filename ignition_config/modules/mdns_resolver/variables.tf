variable "sync_interface_name" {
  type = string
}

variable "mdns_interface_name" {
  type = string
}

variable "mdns_resolver_vip" {
  type = string
}

variable "keepalived_config_path" {
  type    = string
  default = "/etc/keepalived/keepalived.conf.d"
}