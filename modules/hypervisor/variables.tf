variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "hypervisor"
}

variable "interfaces" {
  # {
  #   en0 = {
  #     mac = "8c-8c-aa-e3-58-62"
  #     mtu = 9000
  #     taps = {
  #       lan = {
  #         netnum = 1
  #         mdns = true
  #         dhcp = true
  #       }
  #     }
  #   }
  # }
  type    = any
  default = {}
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

variable "internal_vlan" {
  type    = string
  default = "192.168.224.0/26"
}

variable "ports" {
  type = object({
    matchbox_http = number
    matchbox_rpc  = number
  })
  default = {
    matchbox_http = 80
    matchbox_rpc  = 58081
  }
}

variable "image_paths" {
  type = object({
    matchbox = string
  })
  default = {
    matchbox = "/var/lib/image-load/matchbox.tar"
  }
}

variable "ca" {
  type = object({
    matchbox = object({
      algorithm       = string
      private_key_pem = string
      cert_pem        = string
    })
    libvirt = object({
      algorithm       = string
      private_key_pem = string
      cert_pem        = string
    })
  })
}