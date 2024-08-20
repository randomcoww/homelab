variable "cluster_service_endpoint" {
  type = string
}

variable "release" {
  type = string
}

variable "replicas" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    clickhouse = string
    jfs        = string
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

variable "service_ip" {
  type = string
}

variable "resources" {
  type    = map(any)
  default = {}
}

variable "extra_clickhouse_config" {
  type    = any
  default = {}
}

variable "extra_keeper_config" {
  type    = any
  default = {}
}

variable "volume_claim_templates" {
  type    = any
  default = []
}

variable "extra_volumes" {
  type    = any
  default = []
}

variable "extra_volume_mounts" {
  type    = any
  default = []
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

variable "litestream_minio_bucket_endpoint" {
  type = string
}

variable "litestream_minio_access_key_id" {
  type = string
}

variable "litestream_minio_secret_access_key" {
  type = string
}