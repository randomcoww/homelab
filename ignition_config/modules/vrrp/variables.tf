variable "haproxy_config_path" {
  type    = string
  default = "/etc/haproxy/haproxy.cfg.d"
}

variable "keepalived_config_path" {
  type    = string
  default = "/etc/keepalived/keepalived.conf.d"
}