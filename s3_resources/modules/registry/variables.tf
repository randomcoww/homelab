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

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    registry = string
  })
}

variable "replicas" {
  type    = number
  default = 1
}

variable "ca_issuer_name" {
  type = string
}

variable "config" {
  type    = any
  default = {}
}

variable "service_port" {
  type = number
}

variable "service_ip" {
  type = string
}

variable "service_hostname" {
  type = string
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

variable "minio_user" {
  type = object({
    id     = string
    secret = string
  })
}