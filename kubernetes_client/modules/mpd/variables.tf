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
    mpd     = string
    mympd   = string
    rclone  = string
    juicefs = string
  })
}

variable "extra_configs" {
  type    = any
  default = {}
}

variable "audio_outputs" {
  type    = list(any)
  default = []
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

variable "redis_endpoint" {
  type = string
}

variable "redis_db_id" {
  type = number
}

variable "redis_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
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