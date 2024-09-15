variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    wireproxy = string
  })
}

variable "ports" {
  type = object({
    socks5 = number
  })
}

variable "wireguard_config" {
  type = string
}