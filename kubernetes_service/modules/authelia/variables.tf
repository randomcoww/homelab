variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "helm_template" {
  type = object({
    repository = string
    chart      = string
    version    = string
  })
}

variable "images" {
  type = object({
    litestream = string
  })
}

variable "lldap_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "redis_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "service_hostname" {
  type = string
}

variable "configmap" {
  type    = any
  default = {}
}

variable "secret" {
  type    = any
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "ingress_cert_issuer" {
  type = string
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_litestream_prefix" {
  type = string
}

variable "minio_access_key_id" {
  type = string
}

variable "minio_secret_access_key" {
  type = string
}