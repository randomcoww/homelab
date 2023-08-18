variable "interfaces" {
  type = any
}

variable "container_images" {
  type = map(string)
}

variable "host_netnum" {
  type = number
}

variable "pod_network_prefix" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}

variable "conntrackd_ipv4_ignore" {
  type = list(string)
}

variable "conntrackd_ipv6_ignore" {
  type = list(string)
}

variable "keepalived_config_path" {
  type    = string
  default = "/etc/keepalived/keepalived.conf.d"
}

variable "keepalived_services" {
  type = list(object({
    ip  = string
    dev = string
  }))
}

variable "upstream_dns" {
  type = object({
    ip             = string
    tls_servername = string
  })
}