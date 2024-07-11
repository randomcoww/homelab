variable "name" {
  type = string
}

variable "app" {
  type = string
}

variable "release" {
  type = string
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

variable "litestream_image" {
  type = string
}

variable "litestream_config" {
  type = any
}

variable "sqlite_path" {
  type = string
}