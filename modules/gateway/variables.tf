variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "gateway"
}

variable "networks" {
  # {
  #   lan = {
  #     network = "192.168.126.0/24"
  #     vlan_id = 1
  #   }
  # }
  type    = any
  default = {}
}

variable "interfaces" {
  # {
  #   lan = {
  #     mdns = true
  #     vrrp_netnum = 2
  #   }
  #   sync = {
  #     mdns = true
  #     netnum = 1
  #     vrrp_netnum = 2
  #   }
  #   wan = {
  #     dhcp = true
  #   }
  # }
  type    = any
  default = {}
}

variable "domain_interfaces" {
  # [
  #   {
  #     network_name = "internal"
  #     hypervisor_interface_name = "internal"
  #   },
  #   {
  #     network_name = "lan"
  #     hypervisor_interface_name = "en0-lan"
  #     macaddress = "00-00-00-00-00-00"
  #   },
  #   {
  #     network_name = "sync"
  #     hypervisor_interface_name = "en0-lan"
  #   },
  #   {
  #     network_name = "wan"
  #     hypervisor_interface_name = "en0-lan"
  #   }
  # ]
  type    = any
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

variable "netnum" {
  type = number
}

variable "vrrp_netnum" {
  type = number
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