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
    headscale  = string
    litestream = string
  })
}

variable "ports" {
  type = object({
    headscale      = number
    headscale_grpc = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "private_key" {
  type = string
}

variable "noise_private_key" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "extra_config" {
  type    = any
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
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