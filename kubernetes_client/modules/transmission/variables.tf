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
    transmission = string
    wireguard    = string
    juicefs      = string
  })
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

variable "wireguard_config" {
  type = string
}

variable "torrent_done_script" {
  type = string
}

variable "transmission_settings" {
  type = map(string)
}

variable "transmission_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "blocklist_update_schedule" {
  type    = string
  default = "0 0 * * *"
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

variable "resources" {
  type    = map(any)
  default = {}
}