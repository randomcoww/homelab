variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service_domain" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "images" {
  type = object({
    lldap = object({
      repository = string
      tag        = string
    })
  })
}

variable "affinity" {
  type    = any
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

variable "extra_envs" {
  type    = any
  default = {}
}