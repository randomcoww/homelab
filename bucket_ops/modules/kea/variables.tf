variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "images" {
  type = object({
    kea = object({
      repository = string
      tag        = string
    })
    ipxe = object({
      repository = string
      tag        = string
    })
  })
}

variable "ports" {
  type = object({
    kea_peer  = number
    stork     = number
    ipxe      = number
    ipxe_tftp = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "peer_service_ips" {
  type = list(string)
}

variable "ipxe_boot_file_name" {
  type = string
}

variable "ipxe_script_base_url" {
  type = string
}

variable "dhcp_networks" {
  type = list(object({
    config      = any
    option_data = any
  }))
  default = []
}