variable "name" {
  type = string
}

variable "controller_namespace" {
  type    = string
  default = "default"
}

variable "namespace" {
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

variable "ca_issuer_name" {
  type = string
}

variable "registry_endpoint" {
  type = string
}

variable "minio_endpoint" {
  type = string
}

variable "minio_user" {
  type = object({
    id     = string
    secret = string
  })
}