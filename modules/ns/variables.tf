variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "gateway"
}

variable "networks" {
  type    = any
  default = {}
}

variable "interfaces" {
  type    = any
  default = {}
}

variable "domain_interfaces" {
  type    = any
  default = []
}

variable "container_images" {
  type = map(string)
}

variable "ports" {
  type = object({
    kea_peer     = number
    dns_redirect = number
    pxe_http     = number
  })
  default = {
    kea_peer     = 80
    dns_redirect = 58081
    pxe_http     = 58082
  }
}

variable "upstream_dns" {
  type = object({
    ip             = string
    tls_servername = string
  })
  default = {
    ip             = "9.9.9.9"
    tls_servername = "dns.quad9.net"
  }
}

variable "internal_dns" {
  type = object({
    ip = string
  })
  default = {
    ip = "192.168.126.10"
  }
}

variable "kea_peers" {
  type    = any
  default = []
}

variable "netnum" {
  type = number
}

variable "vrrp_netnum" {
  type = number
}

variable "gateway_netnum" {
  type = number
}

variable "dhcp_server" {
  type = object({
    newbit = number
    netnum = number
  })
}

variable "domains" {
  type = object({
    internal      = string
    internal_mdns = string
  })
}