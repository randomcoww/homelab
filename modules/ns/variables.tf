variable "user" {
  type = any
}

variable "hostname" {
  type = string
}

variable "guest_interfaces" {
  # type = map(object({
  #   enable_mdns        = optional(bool)
  #   enable_netnum      = optional(bool)
  #   enable_vrrp_netnum = optional(bool)
  #   enable_linklocal   = optional(bool)
  #   enable_dhcp        = optional(bool)
  #   enable_dhcp_server = optional(bool)
  #   enable_unmanaged   = optional(bool)
  #   mtu                = optional(number)
  #   metric             = optional(number)
  # }))
  type    = map(map(string))
  default = {}
}

variable "container_images" {
  type    = map(string)
  default = {}
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

variable "netnums" {
  type = object({
    host         = number
    vrrp         = number
    gateway_vrrp = number
  })
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

variable "ssh_ca" {
  type = object({
    algorithm          = string
    private_key_pem    = string
    public_key_openssh = string
  })
}