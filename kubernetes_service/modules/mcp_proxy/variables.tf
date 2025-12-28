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
  default = 2
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "images" {
  type = object({
    mcp_proxy = string
  })
}

variable "config" {
  type = any
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}