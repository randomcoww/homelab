variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "replicas" {
  type    = number
  default = 1
}

variable "images" {
  type = object({
    mountpoint = string
  })
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
  default = []
}

variable "spec" {
  type    = any
  default = {}
}

variable "template_spec" {
  type    = any
  default = {}
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

variable "s3_mount_prefix" {
  type = string
}

variable "s3_mount_path" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}