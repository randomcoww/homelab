variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "annotations" {
  type    = any
  default = {}
}

variable "spec" {
  type    = any
  default = {}
}