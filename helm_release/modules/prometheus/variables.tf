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
    thanos = string
  })
}

variable "scrape_configs" {
  type    = any
  default = []
}

variable "server_files" {
  type    = any
  default = {}
}

variable "cluster_domain" {
  type = string
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

variable "minio_access_secret" {
  type = string
}