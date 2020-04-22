variable "user" {
  type = string
}

variable "password" {
  type = string
}

variable "mtu" {
  type = number
}

variable "networks" {
  type = any
}

variable "desktop_hosts" {
  type = any
}

variable "internal_ca_cert_pem" {
  type = string
}