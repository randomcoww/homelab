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
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    open_webui = string
    litestream     = string
  })
}

variable "resources" {
  type    = any
  default = {}
}

variable "security_context" {
  type    = any
  default = {}
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

variable "minio_litestream_prefix" {
  type = string
}

variable "minio_access_key_id" {
  type = string
}

variable "minio_secret_access_key" {
  type = string
}