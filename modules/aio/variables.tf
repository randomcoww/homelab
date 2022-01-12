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

variable "container_images" {
  type    = map(string)
  default = {}
}

variable "netnums" {
  type = object({
    host = number
    vrrp = number
  })
}

variable "dhcp_server_subnet" {
  type = object({
    newbit = number
    netnum = number
  })
}

variable "kea_peers" {
  type = map(map(string))
}

variable "internal_dns_ip" {
  type = string
}

variable "internal_domain" {
  type = string
}

variable "pxeboot_file_name" {
  type = string
}

variable "container_storage_path" {
  type = string
}