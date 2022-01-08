variable "name" {
  type = string
}

variable "libvirt_interfaces" {
  type    = map(string)
  default = {}
}

variable "interface_device_order" {
  type    = list(string)
  default = []
}

variable "hypervisor_devices" {
  type    = list(map(string))
  default = []
}

variable "system_image_tag" {
  type = string
}

variable "vcpus" {
  type = number
}

variable "memory" {
  type = number
}