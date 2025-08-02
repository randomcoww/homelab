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
    ipxe        = string
    ipxe_tftp   = string
    stork_agent = string
  })
}

variable "ports" {
  type = object({
    kea_peer       = number
    kea_metrics    = number
    kea_ctrl_agent = number
    ipxe           = number
    ipxe_tftp      = number
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

variable "timezone" {
  type = string
}

variable "stork_agent_token" {
  type = string
}