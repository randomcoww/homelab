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

variable "master_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
}

variable "slave_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
}

variable "container_images" {
  type = map(string)
}

variable "netnums" {
  type = object({
    host = number
    vrrp = number
  })
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