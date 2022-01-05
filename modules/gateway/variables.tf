variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "gateway"
}

variable "vlans" {
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
  #     vrrp_netnums = [
  #       1,
  #     ]
  #   }
  #   sync = {
  #     mdns = true
  #     netnum = 1
  #     vrrp_netnums = [
  #       1,
  #     ]
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
  type = object({
    conntrackd = string
    kubelet    = string
  })
}

variable "upstream_dns" {
  type = object({
    ip  = string
    url = string
  })
  default = {
    ip  = "9.9.9.9"
    url = "dns.quad9.net"
  }
}