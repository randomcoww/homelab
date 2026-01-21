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

variable "images" {
  type = object({
    kavita     = string
    mountpoint = string
    litestream = string
  })
}

variable "extra_configs" {
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

variable "minio_data_bucket" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_access_secret" {
  type = string
}

variable "ingress_hostname" {
  type = string
}