variable "cluster_service_endpoint" {
  type = string
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    lldap      = string
    litestream = string
  })
}

variable "ports" {
  type = object({
    lldap_ldaps = number
  })
}

variable "affinity" {
  type    = any
  default = {}
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

variable "storage_secret" {
  type = string
}

variable "extra_configs" {
  type    = map(any)
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "litestream_minio_bucket" {
  type = string
}

variable "litestream_minio_endpoint" {
  type = string
}

variable "litestream_minio_access_key_id" {
  type = string
}

variable "litestream_minio_secret_access_key" {
  type = string
}