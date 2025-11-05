variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    lldap      = string
    litestream = string
  })
}

variable "ports" {
  type = object({
    ldaps = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ca_issuer_name" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "ingress_hostname" {
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

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_access_secret" {
  type = string
}

variable "ca_bundle_configmap" {
  type = string
}