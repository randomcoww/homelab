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
    code_server = string
    tailscale   = string
  })
}

variable "ports" {
  type = object({
    code_server = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "ssh_known_hosts" {
  type    = list(string)
  default = []
}

variable "service_hostname" {
  type = string
}

variable "code_server_extra_envs" {
  type    = map(any)
  default = {}
}

variable "tailscale_extra_envs" {
  type    = map(any)
  default = {}
}

variable "code_server_resources" {
  type    = any
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "ingress_cert_issuer" {
  type = string
}

variable "ingress_auth_url" {
  type = string
}

variable "ingress_auth_signin" {
  type = string
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

variable "volume_claim_size" {
  type = string
}

variable "storage_class" {
  type = string
}

variable "storage_access_modes" {
  type = list(string)
  default = [
    "ReadWriteOnce",
  ]
}