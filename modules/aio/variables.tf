variable "name" {
  type = string
}

variable "user" {
  type = any
}

variable "hostname" {
  type = string
}

variable "networks" {
  type = map(object({
    network = optional(string)
    cidr    = optional(string)
    prefix  = optional(string)
    vlan_id = optional(number)
  }))
  default = {}
}

variable "tap_interfaces" {
  type = map(map(string))
}

variable "hardware_interfaces" {
  type    = any
  default = {}
}

variable "kea_peers" {
  type = map(map(string))
}

variable "netnums" {
  type = object({
    host = number
    vrrp = number
  })
}

variable "kea_hooks_libraries_path" {
  type    = string
  default = "/usr/local/lib/kea/hooks"
}

variable "kea_shared_path" {
  type    = string
  default = "/var/lib/kea"
}

variable "master_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
  default = {
    table_id       = 250
    table_priority = 32770
  }
}

variable "slave_default_route" {
  type = object({
    table_id       = number
    table_priority = number
  })
  default = {
    table_id       = 240
    table_priority = 32780
  }
}

variable "pxeboot_file_name" {
  type = string
}

variable "container_images" {
  type    = map(string)
  default = {}
}

variable "upstream_dns_ip" {
  type    = string
  default = "9.9.9.9"
}

variable "upstream_dns_tls_servername" {
  type    = string
  default = "dns.quad9.net"
}

variable "internal_dns_ip" {
  type = string
}

variable "internal_domain" {
  type = string
}

variable "dhcp_server" {
  type = object({
    newbit = number
    netnum = number
  })
}

variable "libvirt_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}