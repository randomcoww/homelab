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

variable "affinity" {
  type    = any
  default = {}
}

variable "extra_api_envs" {
  type    = map(string)
  default = {}
}

variable "extra_api_secrets" {
  type    = map(string)
  default = {}
}

variable "extra_controlplane_secrets" {
  type    = map(string)
  default = {}
}

variable "ca_issuer_name" {
  type = string
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}