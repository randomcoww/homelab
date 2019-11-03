variable "user" {
  type = string
}

variable "password" {
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

variable "live_hosts" {
  type = any
}

variable "kvm_hosts" {
  type = any
}

variable "desktop_hosts" {
  type = any
}

variable "renderer" {
  type = map(string)
}