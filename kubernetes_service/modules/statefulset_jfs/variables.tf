variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    jfs        = string
    litestream = string
  })
}

variable "replicas" {
  type    = number
  default = 1
}

variable "annotations" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "tolerations" {
  type    = any
  default = []
}

variable "spec" {
  type    = any
  default = {}
}

variable "template_spec" {
  type    = any
  default = {}
}

variable "jfs_mount_path" {
  type = string
}

variable "jfs_capacity_gb" {
  type    = number
  default = 0
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_jfs_prefix" {
  type    = string
  default = "$(POD_NAME)"
}

variable "minio_litestream_prefix" {
  type    = string
  default = "$POD_NAME/litestream"
}

variable "minio_access_secret" {
  type = string
}

variable "ca_bundle_configmap" {
  type = string
}