variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "images" {
  type = object({
    sunshine-desktop = object({
      repository = string
      tag        = string
    })
    nginx = object({
      repository = string
      tag        = string
    })
  })
}

variable "extra_envs" {
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

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "extra_volume_mounts" {
  type    = any
  default = []
}

variable "extra_volumes" {
  type    = any
  default = []
}

variable "gpu_resource_claim" {
  type = string
}

variable "storage_class_name" {
  type = string
}

variable "auth_backend_ref" {
  type = object({
    name      = string
    namespace = string
    port      = number
  })
}