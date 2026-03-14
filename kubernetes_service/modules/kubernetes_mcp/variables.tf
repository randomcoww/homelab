variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "replicas" {
  type    = number
  default = 2
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    kubernetes_mcp = string
    nginx          = string
  })
}

variable "extra_configs" {
  type    = map(string)
  default = {}
}

variable "oauth_client_id" {
  type = string
}

variable "oauth_authorization_url" {
  type = string
}

variable "oauth_scopes" {
  type = list(string)
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}