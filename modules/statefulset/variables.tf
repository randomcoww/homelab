variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "labels" {
  type    = any
  default = {}
}

variable "replicas" {
  type    = number
  default = 1
}

variable "annotations" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "tolerations" {
  type    = any
  default = []
}

variable "spec" {
  type    = any
  default = {}
}

variable "template_spec" {
  type    = any
  default = {}
}