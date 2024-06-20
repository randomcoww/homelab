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

variable "ports" {
  type = object({
    qrcode = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "qrcodes" {
  type = map(object({
    service_hostname = string
    code             = string
  }))
}