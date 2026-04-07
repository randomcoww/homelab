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

variable "replicas" {
  type    = number
  default = 1
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "images" {
  type = object({
    open_webui     = string
    litestream     = string
    kubernetes_mcp = string
    prometheus_mcp = string
  })
}

variable "internal_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "prometheus_endpoint" {
  type = string
}

variable "extra_configs" {
  type    = map(string)
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
