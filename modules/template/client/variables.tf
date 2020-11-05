variable "client_password" {
  type = string
}

variable "domains" {
  type = map(string)
}

variable "wireguard_config" {
  type = any
}

variable "hosts" {
  type = any
}