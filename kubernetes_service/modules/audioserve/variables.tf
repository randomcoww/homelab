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
    audioserve = string
    mountpoint = string
  })
}

variable "transcoding_config" {
  type    = any
  default = {}
}

variable "extra_audioserve_args" {
  type    = list(string)
  default = []
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

variable "minio_access_secret" {
  type = string
}