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
    s3fs       = string
  })
}

variable "ports" {
  type = object({
    clickhouse = number
    metrics    = number
  })
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "service_hostname" {
  type = string
}

variable "service_ip" {
  type    = string
  default = ""
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

variable "extra_users_config" {
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

variable "loadbalancer_class_name" {
  type = string
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