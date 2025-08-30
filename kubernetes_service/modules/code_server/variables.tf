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
    jfs         = string
    litestream  = string
  })
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "extra_configs" {
  type = list(object({
    path    = string
    content = string
  }))
  default = []
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "resources" {
  type    = any
  default = {}
}

variable "security_context" {
  type    = any
  default = {}
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

variable "extra_volume_mounts" {
  type    = any
  default = []
}

variable "extra_volumes" {
  type    = any
  default = []
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_access_key_id" {
  type = string
}

variable "minio_secret_access_key" {
  type = string
}