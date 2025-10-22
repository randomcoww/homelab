variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    juicefs    = string
    litestream = string
  })
}

variable "template_spec" {
  type    = any
  default = {}
}

variable "mount_path" {
  type = string
}

variable "capacity_gb" {
  type = number
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_prefix" {
  type = string
}

variable "minio_access_secret" {
  type = string
}

variable "ca_bundle_configmap" {
  type = string
}