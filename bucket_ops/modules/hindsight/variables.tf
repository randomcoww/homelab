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

variable "service_port" {
  type = number
}

variable "extra_envs" {
  type    = any
  default = {}
}

variable "extra_secrets" {
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

variable "auth_backend_ref" {
  type = object({
    name      = string
    namespace = string
    port      = number
  })
}
