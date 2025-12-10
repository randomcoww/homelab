variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    mountpoint = string
  })
}

variable "template_spec" {
  type    = any
  default = {}
}

variable "mount_path" {
  type = string
}

variable "s3_endpoint" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_prefix" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}

variable "s3_access_secret" {
  type = string
}
