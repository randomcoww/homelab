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
    registry = string
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

variable "service_ip" {
  type = string
}

variable "loadbalancer_class_name" {
  type = string
}

# TLS for this instance
variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "resources" {
  type    = any
  default = {}
}

variable "config" {
  type    = any
  default = {}
}

variable "s3_endpoint" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_bucket_prefix" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}