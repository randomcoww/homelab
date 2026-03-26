variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
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
    navidrome  = string
    mountpoint = string
    litestream = string
  })
}

variable "extra_configs" {
  type    = any
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "auth_middleware" {
  type    = any
  default = {}
}

variable "gateway_ref" {
  type = any
}

variable "middleware_ref" {
  type = object({
    name      = string
    namespace = string
  })
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