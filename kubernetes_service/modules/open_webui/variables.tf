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
    open_webui = string
    litestream = string
  })
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "extra_configs" {
  type    = map(string)
  default = {}
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
