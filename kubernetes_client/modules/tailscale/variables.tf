variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    tailscale = string
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "tailscale_extra_envs" {
  type    = map(any)
  default = {}
}

variable "tailscale_auth_key" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ssm_access_key_id" {
  type = string
}

variable "ssm_secret_access_key" {
  type = string
}

variable "ssm_tailscale_resource" {
  type = string
}