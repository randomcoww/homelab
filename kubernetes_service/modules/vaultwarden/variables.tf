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

variable "images" {
  type = object({
    vaultwarden = string
  })
}

variable "replicas" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_hostname" {
  type = string
}

variable "extra_configs" {
  type    = map(any)
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}