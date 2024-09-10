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

variable "app_version" {
  type    = string
  default = "0.1.0"
}

variable "manifests" {
  type = map(string)
}