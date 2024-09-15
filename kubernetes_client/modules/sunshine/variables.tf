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
    sunshine   = string
    mountpoint = string
  })
}

variable "sunshine_extra_args" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "sunshine_extra_configs" {
  type = list(object({
    path    = string
    content = string
  }))
  default = []
}

variable "sunshine_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "sunshine_resources" {
  type    = any
  default = {}
}

variable "sunshine_security_context" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "service_hostname" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "admin_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "sunshine_extra_volume_mounts" {
  type    = any
  default = []
}

variable "sunshine_extra_volumes" {
  type    = any
  default = []
}

variable "s3_mount_access_key_id" {
  type = string
}

variable "s3_mount_secret_access_key" {
  type = string
}

variable "s3_mount_endpoint" {
  type = string
}

variable "s3_mount_bucket" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}