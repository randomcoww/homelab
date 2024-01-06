variable "name" {
  type = string
}

variable "release" {
  type = string
}

variable "image" {
  type = string
}

variable "replicas" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "bssid_base" {
  type    = number
  default = 20000000000000
}

variable "config" {
  type = any
}