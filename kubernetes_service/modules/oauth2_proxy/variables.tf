variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    oauth2_proxy = string
  })
}

variable "extra_args" {
  type    = list(string)
  default = []
}

variable "ingress_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}