variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "rules" {
  type    = any
  default = []
}

variable "annotations" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "tolerations" {
  type    = any
  default = {}
}

variable "spec" {
  type    = any
  default = {}
}

variable "cert_issuer" {
  type = string
}

variable "auth_url" {
  type = string
}

variable "auth_signin" {
  type = string
}

variable "wildcard_domain" {
  type = string
}