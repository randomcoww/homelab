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

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    mpd        = string
    mympd      = string
    rclone     = string
    jfs        = string
    litestream = string
  })
}

variable "extra_configs" {
  type    = any
  default = {}
}

variable "data_minio_endpoint" {
  type = string
}

variable "data_minio_bucket" {
  type = string
}

variable "data_minio_access_key_id" {
  type = string
}

variable "data_minio_secret_access_key" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "resources" {
  type    = map(any)
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "jfs_minio_endpoint" {
  type = string
}

variable "jfs_minio_bucket" {
  type = string
}

variable "jfs_minio_prefix" {
  type    = string
  default = "$(POD_NAME)"
}

variable "jfs_minio_access_key_id" {
  type = string
}

variable "jfs_minio_secret_access_key" {
  type = string
}

variable "litestream_minio_endpoint" {
  type = string
}

variable "litestream_minio_bucket" {
  type = string
}

variable "litestream_minio_prefix" {
  type    = string
  default = "$POD_NAME"
}

variable "litestream_minio_access_key_id" {
  type = string
}

variable "litestream_minio_secret_access_key" {
  type = string
}