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
  default = 2
}

variable "images" {
  type = object({
    lldap = string
  })
}

variable "service_port" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ca_issuer_name" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "extra_configs" {
  type    = map(any)
  default = {}
}