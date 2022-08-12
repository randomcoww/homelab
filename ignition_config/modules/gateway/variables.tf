variable "interfaces" {
  type = any
}

variable "container_images" {
  type = map(string)
}

variable "host_netnum" {
  type = number
}

variable "vrrp_netnum" {
  type = number
}

variable "external_ingress_ip" {
  type = string
}

variable "pod_network_prefix" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}

variable "haproxy_config_path" {
  type    = string
  default = "/etc/haproxy/haproxy.cfg.d"
}

variable "members" {
  type = map(object({
    netnum = number
  }))
}