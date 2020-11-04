variable "client_password" {
  type = string
}

variable "domains" {
  type = map(string)
}

variable "wireguard_config" {
  type = any
}

variable "swap_device" {
  type = string
}

variable "hosts" {
  type = any
}