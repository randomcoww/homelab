variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
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