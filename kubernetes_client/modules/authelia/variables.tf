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

variable "source_release" {
  type = string
}

variable "images" {
  type = object({
    litestream = string
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

variable "s3_db_resource" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}