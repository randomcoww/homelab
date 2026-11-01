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

variable "ca_issuer_name" {
  type = string
}

variable "oidc_client_id" {
  type = string
}

variable "oidc_client_secret" {
  type = string
}

variable "oidc_issuer_url" {
  type = string
}

variable "oidc_scopes" {
  type = list(string)
}

variable "ingress_hostname" {
  type = string
}

variable "openai_endpoint" {
  type = string
}

variable "openai_apikey" {
  type = string
}

variable "gateway_ref" {
  type = any
}
