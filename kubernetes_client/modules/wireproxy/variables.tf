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

variable "wireguard_config" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "service_ip" {
  type = string
}