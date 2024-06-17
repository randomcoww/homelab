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
    code_server = string
    litestream  = string
    juicefs     = string
  })
}

variable "ports" {
  type = object({
    code_server = number
  })
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "code_server_extra_configs" {
  type = list(object({
    path    = string
    content = string
  }))
  default = []
}

variable "code_server_extra_envs" {
  type    = map(any)
  default = {}
}

variable "code_server_resources" {
  type    = any
  default = {}
}

variable "jfs_minio_endpoint" {
  type = string
}

variable "jfs_minio_bucket" {
  type = string
}

variable "jfs_minio_access_key_id" {
  type = string
}

variable "jfs_minio_secret_access_key" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}