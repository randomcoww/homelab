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
    litestream  = string
  })
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