variable "user" {
  type = string
}

variable "ssh_ca_public_key" {
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

variable "gateway_hosts" {
  type = any
}