variable "user" {
  type    = string
  default = "fcos"
}

variable "hostname" {
  type    = string
  default = "gateway"
}

variable "networks" {
  type    = any
  default = {}
}

variable "interfaces" {
  type    = any
  default = {}
}

variable "domain_interfaces" {
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

variable "netnums" {
  type = object({
    host = number
    vrrp = number
  })
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