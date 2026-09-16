variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 2
}

variable "images" {
  type = object({
    ipxe-presign = object({
      repository = string
      tag        = string
    })
  })
}

variable "service_port" {
  type = number
}

variable "service_ip" {
  type = string
}

variable "extra_configs" {
  type = any
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ca_issuer_name" {
  type = string
}

variable "minio_user" {
  type = object({
    id     = string
    secret = string
  })
}