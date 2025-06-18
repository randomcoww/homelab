variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "annotations" {
  type    = any
  default = {}
}

variable "rules" {
  type    = any
  default = []
}

variable "spec" {
  type    = any
  default = {}
}