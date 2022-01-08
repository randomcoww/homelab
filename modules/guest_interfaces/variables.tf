variable "networks" {
  type = map(object({
    network = optional(string)
    cidr    = optional(string)
    prefix  = optional(string)
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
  #   enable_unmanaged   = optional(bool)
  #   mtu                = optional(number)
  #   metric             = optional(number)
  # }))
  type    = map(map(string))
  default = {}
}

variable "guest_interface_device_order" {
  type    = list(string)
  default = []
}

variable "host_netnum" {
  type = number
}