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

variable "source_release" {
  type = string
}

variable "images" {
  type = object({
    litestream = string
  })
}

variable "service_hostname" {
  type = string
}

variable "access_control" {
  type    = any
  default = {}
}

variable "users" {
  type    = any
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

variable "jwt_token" {
  type = string
}

variable "storage_secret" {
  type = string
}

variable "session_encryption_key" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "ingress_cert_issuer" {
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