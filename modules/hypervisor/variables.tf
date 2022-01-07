variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "hypervisor"
}

variable "networks" {
  type = map(object({
    network = optional(string)
    cidr    = optional(string)
    vlan_id = optional(number)
  }))
  default = {}
}

variable "hardware_interfaces" {
  type    = any
  default = {}
}

variable "internal_interface" {
  type = object({
    interface_name = string
    netnum         = number
    dhcp_subnet = object({
      newbit = number
      netnum = number
    })
  })
  default = {
    interface_name = "internal"
    netnum         = 1
    dhcp_subnet = {
      newbit = 1
      netnum = 1
    }
  }
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

variable "container_image_load_paths" {
  type = map(string)
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