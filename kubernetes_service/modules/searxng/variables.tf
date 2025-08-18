variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "replicas" {
  type    = number
  default = 1
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ports" {
  type = object({
    searxng = number
  })
}

variable "images" {
  type = object({
    searxng = string
    valkey  = string
  })
}

variable "searxng_settings" {
  type    = any
  default = {}
}

variable "resources" {
  type    = any
  default = {}
}

variable "extra_configs" {
  type    = map(string)
  default = {}
}