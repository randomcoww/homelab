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
    litestream = string
  })
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

variable "minio_access_secret" {
  type = string
}

variable "ca_bundle_configmap" {
  type = string
}