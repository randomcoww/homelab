variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "images" {
  type = object({
    thanos = object({
      registry   = string
      repository = string
      tag        = string
    })
  })
}

variable "extra_scrape_configs" {
  type    = any
  default = []
}

variable "extra_rules_map" {
  type    = any
  default = {}
}

variable "extra_values" {
  type    = any
  default = {}
}

variable "extra_manifests" {
  type    = any
  default = []
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "minio_endpoint" {
  type = string
}

variable "minio_bucket" {
  type = string
}

variable "minio_user" {
  type = object({
    id     = string
    secret = string
  })
}