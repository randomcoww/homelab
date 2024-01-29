variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "spec" {
  type    = any
  default = {}
}