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

variable "spec" {
  type    = any
  default = {}
}