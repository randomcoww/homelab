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
    caddy_webdav = string
    mountpoint   = string
  })
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

variable "s3_endpoint" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}