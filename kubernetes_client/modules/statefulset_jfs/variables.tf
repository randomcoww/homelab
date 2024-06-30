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

variable "min_ready_seconds" {
  type    = number
  default = 0
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

variable "volume_claim_templates" {
  type    = any
  default = []
}

variable "jfs_image" {
  type = string
}

variable "jfs_mount_path" {
  type = string
}

variable "jfs_minio_resource" {
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