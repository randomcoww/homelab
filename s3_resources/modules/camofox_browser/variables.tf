variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 1
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    camofox_browser = string
  })
}

variable "extra_configs" {
  type    = map(any)
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}