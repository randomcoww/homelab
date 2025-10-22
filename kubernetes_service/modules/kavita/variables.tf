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
    kavita     = string
    mountpoint = string
    litestream = string
  })
}

variable "resources" {
  type    = any
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

variable "minio_mount_extra_args" {
  type    = list(string)
  default = []
}

variable "minio_litestream_bucket" {
  type = string
}

variable "minio_litestream_prefix" {
  type = string
}

variable "minio_access_secret" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "ca_bundle_configmap" {
  type = string
}