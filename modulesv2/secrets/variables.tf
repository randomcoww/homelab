variable "networks" {
  type = any
}

variable "domains" {
  type = any
}

variable "s3_secrets_bucket" {
  type = string
}

variable "s3_secrets_key" {
  type = string
}

variable "secrets" {
  type = any
}

variable "wireguard_client_hosts" {
  type = any
}

variable "wireguard_client_templates" {
  type = list(string)
}

variable "internal_tls_hosts" {
  type = any
}

variable "internal_tls_templates" {
  type = list(string)
}

variable "addon_templates" {
  type = map(string)
}