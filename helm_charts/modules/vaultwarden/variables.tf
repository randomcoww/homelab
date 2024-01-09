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
    vaultwarden = string
    litestream  = string
  })
}

variable "ports" {
  type = object({
    vaultwarden = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_hostname" {
  type = string
}

variable "exrtra_envs" {
  type    = map(any)
  default = {}
}

variable "smtp_host" {
  type = string
}

variable "smtp_port" {
  type = string
}

variable "smtp_username" {
  type = string
}

variable "smtp_password" {
  type = string
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

variable "s3_db_resource" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}