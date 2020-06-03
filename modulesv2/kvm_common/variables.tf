variable "user" {
  type = string
}

variable "mtu" {
  type = number
}

variable "networks" {
  type = any
}

variable "services" {
  type = any
}

variable "domains" {
  type = map(string)
}

variable "container_images" {
  type = map(string)
}

variable "image_device" {
  type = any
}

variable "kvm_hosts" {
  type = any
}

variable "kvm_templates" {
  type = list(string)
}