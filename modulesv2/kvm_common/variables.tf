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
  type = any
}

variable "container_images" {
  type = any
}

variable "kvm_hosts" {
  type = any
}

variable "kvm_templates" {
  type = list(string)
}