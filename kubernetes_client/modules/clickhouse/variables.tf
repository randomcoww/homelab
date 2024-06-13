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
    clickhouse = string
    litestream = string
  })
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "clickhouse_config" {
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

variable "cluster_service_endpoint" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "resources" {
  type    = map(any)
  default = {}
}