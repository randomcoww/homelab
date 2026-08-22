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
    gha-runner = object({
      repository = string
      tag        = string
    })
  })
}

variable "github_username" {
  type = string
}

variable "github_renovate_token" {
  type = string
}

variable "github_runner_token" {
  type = string
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

variable "cosa_build_tag_karg" {
  type = string
}