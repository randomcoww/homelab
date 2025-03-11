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
    kea         = string
    tftpd       = string
    stork_agent = string
  })
}

variable "ports" {
  type = object({
    kea_peer    = number
    kea_metrics = number
    tftpd       = number
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

variable "ipxe_boot_url" {
  type = string
}

variable "ipxe_script_url" {
  type = string
}

variable "networks" {
  type = list(object({
    prefix              = string
    mtu                 = number
    routers             = optional(list(string), [])
    domain_name_servers = optional(list(string), [])
    domain_search       = optional(list(string), [])
    pools               = list(string)
  }))
}

variable "kea_hooks_libraries_path" {
  type    = string
  default = "/usr/local/lib/kea/hooks"
}

variable "timezone" {
  type = string
}