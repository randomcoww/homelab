variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
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

variable "images" {
  type = object({
    hermes_agent = string
    litestream   = string
    juicefs      = string
  })
}

variable "extra_configs" {
  type    = any
  default = {}
}

variable "extra_envs" {
  type    = map(string)
  default = {}
}

variable "extra_dbs" {
  type    = list(string)
  default = []
}

variable "extra_files" {
  type    = map(string)
  default = {}
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

variable "mcp_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}