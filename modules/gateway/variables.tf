variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "gateway"
}

variable "networks" {
  type = map(object({
    network = optional(string)
    cidr    = optional(string)
    vlan_id = optional(number)
  }))
  default = {}
}

variable "interfaces" {
  # type = map(object({
  #   enable_mdns        = optional(bool)
  #   enable_netnum      = optional(bool)
  #   enable_vrrp_netnum = optional(bool)
  #   enable_linklocal   = optional(bool)
  #   enable_dhcp        = optional(bool)
  #   enable_dhcp_server = optional(bool)
  #   mtu                = optional(number)
  #   metric             = optional(number)
  # }))
  type    = any
  default = {}
}

variable "domain_interfaces" {
  # type = list(object({
  #   network_name              = string
  #   hypervisor_interface_name = string
  #   boot_order                = optional(number)
  # }))
  type    = list(map(string))
  default = []
}

variable "hypervisor_devices" {
  # type = list(object({
  #   domain        = string
  #   bus           = string
  #   slot          = string
  #   function      = string
  #   rom_file_path = optional(string)
  # }))
  type    = list(map(string))
  default = []
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