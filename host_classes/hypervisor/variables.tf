variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "hypervisor"
}

variable "networks" {
  # {
  #   lan = {
  #     network = "192.168.126.0"
  #     cidr = 24
  #     vlan_id = 1
  #   }
  #   internal = {
  #     network = "192.168.224.0"
  #     cidr = 28
  #     vlan_id = 100
  #   }
  # }
  type    = any
  default = {}
}

variable "hardware_interfaces" {
  # {
  #   en0 = {
  #     mac = "8c-8c-aa-e3-58-62"
  #     mtu = 9000
  #     networks = {
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

variable "container_image_paths" {
  type = object({
    matchbox = string
  })
  default = {
    matchbox = "/var/lib/image-load/matchbox.tar"
  }
}

variable "matchbox_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "libvirt_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "ssh_ca" {
  type = object({
    algorithm          = string
    private_key_pem    = string
    public_key_openssh = string
  })
}