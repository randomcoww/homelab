variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    kea   = string
    tftpd = string
  })
}

variable "ports" {
  type = object({
    kea_peer = number
    tftpd    = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_ips" {
  type = list(string)
}

variable "ipxe_boot_path" {
  type = string
}

variable "ipxe_script_url" {
  type = string
}

variable "networks" {
  type = list(object({
    prefix              = string
    mtu                 = number
    routers             = list(string)
    domain_name_servers = list(string)
    domain_search       = list(string)
    pools               = list(string)
  }))
}

variable "kea_hooks_libraries_path" {
  type    = string
  default = "/usr/local/lib/kea/hooks"
}