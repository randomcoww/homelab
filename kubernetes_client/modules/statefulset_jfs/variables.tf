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

variable "jfs_image" {
  type = string
}

variable "jfs_mount_path" {
  type = string
}

variable "jfs_minio_bucket_endpoint" {
  type = string
}

variable "jfs_minio_access_key_id" {
  type = string
}

variable "jfs_minio_secret_access_key" {
  type = string
}

variable "litestream_image" {
  type = string
}

variable "litestream_minio_bucket_endpoint" {
  type = string
}

variable "litestream_minio_access_key_id" {
  type = string
}

variable "litestream_minio_secret_access_key" {
  type = string
}