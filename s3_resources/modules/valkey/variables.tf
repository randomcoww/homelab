variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 3
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    valkey = string
  })
}

variable "service_port" {
  type = number
}

variable "ca_issuer_name" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "resources" {
  type    = any
  default = {}
}