variable "name" {
  type = string
}

variable "namespace" {
  type = string
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
    registry    = string
    registry_ui = string
  })
}

variable "ports" {
  type = object({
    registry = number
  })
}

variable "replicas" {
  type    = number
  default = 1
}

variable "loadbalancer_class_name" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "config" {
  type    = any
  default = {}
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_bucket_prefix" {
  type = string
}

variable "minio_access_secret" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "ingress_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}