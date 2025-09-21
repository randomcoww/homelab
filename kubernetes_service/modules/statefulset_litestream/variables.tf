variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "app" {
  type = string
}

variable "release" {
  type = string
}

variable "images" {
  type = object({
    litestream = string
  })
}

variable "replicas" {
  type    = number
  default = 1
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

variable "litestream_config" {
  type = any
}

variable "sqlite_path" {
  type = string
}

variable "s3_ca_cert" {
  type = string
}