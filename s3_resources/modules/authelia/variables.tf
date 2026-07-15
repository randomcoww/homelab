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
  default = 2
}

variable "affinity" {
  type    = any
  default = {}
}

variable "oidc_clients" {
  type    = any
  default = {}
}

variable "oidc_claims_policies" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    authelia = object({
      registry   = string
      repository = string
      tag        = string
    })
  })
}

variable "metrics_port" {
  type = number
}

variable "gateway_ref" {
  type = object({
    name      = string
    namespace = string
  })
}

variable "ca_issuer_name" {
  type = string
}

variable "smtp" {
  type = object({
    host     = string
    port     = number
    username = string
    password = string
  })
}

variable "ldap_credentials" {
  type = object({
    username = string
    password = string
  })
}

variable "ingress_hostname" {
  type = string
}

variable "ldap_endpoint" {
  type = string
}

variable "redis_sentinel_endpoint" {
  type = object({
    host        = string
    port        = number
    master_name = string
  })
}