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

variable "replicas" {
  type    = number
  default = 1
}

variable "images" {
  type = object({
    matchbox   = string
    mountpoint = string
  })
}

variable "ports" {
  type = object({
    matchbox     = number
    matchbox_api = number
  })
}

variable "api_service_ip" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "loadbalancer_class_name" {
  type = string
}

variable "ca_issuer_name" {
  type = string
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

variable "minio_mount_extra_args" {
  type    = list(string)
  default = []
}

variable "ca_bundle_configmap" {
  type = string
}