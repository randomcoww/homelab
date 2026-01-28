variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "llama_swap_config" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    llama_cpp  = string
    llama_swap = string
    rclone     = string
  })
}

variable "api_keys" {
  type    = list(string)
  default = []
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "minio_endpoint" {
  type = string
}

variable "minio_data_bucket" {
  type = string
}

variable "minio_access_secret" {
  type = string
}

variable "ingress_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "storage_class_name" {
  type = string
}