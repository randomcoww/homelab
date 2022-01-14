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

variable "host_netnum" {
  type = number
}