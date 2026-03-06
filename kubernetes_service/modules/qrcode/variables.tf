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

variable "images" {
  type = object({
    qrcode = string
  })
}

variable "replicas" {
  type    = number
  default = 1
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "qrcode_value" {
  type = string
}