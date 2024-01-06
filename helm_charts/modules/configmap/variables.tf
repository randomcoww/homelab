variable "name" {
  type = string
}

variable "release" {
  type = string
}

variable "strategy" {
  type = string
}

variable "annotations" {
  type    = any
  default = {}
}

variable "data" {
  type    = any
  default = {}
}