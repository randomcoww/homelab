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

variable "ingress_class_name" {
  type = string
}

variable "ingress_annotations" {
  type    = map(string)
  default = {}
}

variable "qrcode_value" {
  type = string
}