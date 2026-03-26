variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "images" {
  type = object({
    lldap      = string
    litestream = string
  })
}

variable "ports" {
  type = object({
    ldaps = number
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

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "extra_configs" {
  type    = map(any)
  default = {}
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_access_secret" {
  type = string
}