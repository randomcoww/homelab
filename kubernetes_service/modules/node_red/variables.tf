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
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    s3fs     = string
    node_red = string
  })
}

variable "resources" {
  type    = any
  default = {}
}

variable "security_context" {
  type    = any
  default = {}
}

variable "extra_envs" {
  type    = map(string)
  default = {}
}

variable "s3_endpoint" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}

variable "service_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}