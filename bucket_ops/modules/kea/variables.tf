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
    kea_peer    = number
    kea_metrics = number
    ipxe        = number
    ipxe_tftp   = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_ips" {
  type = list(string)
}

variable "ipxe_boot_file_name" {
  type = string
}

variable "ipxe_script_base_url" {
  type = string
}

variable "networks" {
  type = list(object({
    prefix                 = string
    interface              = string
    routers                = optional(list(string), [])
    domain_name_servers    = optional(list(string), [])
    domain_search          = optional(list(string), [])
    classless_static_route = optional(list(string), [])
    mtu                    = number
  }))
}

variable "timezone" {
  type = string
}