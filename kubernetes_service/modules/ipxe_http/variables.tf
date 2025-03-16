variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "replicas" {
  type    = number
  default = 2
}

variable "images" {
  type = object({
    ipxe_http = string
  })
}

variable "ports" {
  type = object({
    ipxe_http = number
  })
}

variable "loadbalancer_class_name" {
  type = string
}