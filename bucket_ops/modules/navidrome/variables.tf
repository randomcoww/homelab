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
    navidrome = object({
      repository = string
      tag        = string
    })
    litestream = object({
      repository = string
      tag        = string
    })
  })
}

variable "extra_envs" {
  type    = any
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "auth_backend_ref" {
  type = object({
    name      = string
    namespace = string
    port      = number
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

variable "minio_user" {
  type = object({
    id     = string
    secret = string
  })
}