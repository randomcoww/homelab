variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "runner_namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "images" {
  type = object({
    gha_runner = string
  })
}

variable "github_credentials" {
  type = object({
    token    = string
    username = string
  })
}

variable "internal_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "registry_endpoint" {
  type = string
}

variable "minio_endpoint" {
  type = string
}

variable "minio_access_secret" {
  type = string
}