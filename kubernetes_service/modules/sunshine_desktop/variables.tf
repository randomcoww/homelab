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
    sunshine_desktop = string
    nginx            = string
  })
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "extra_configs" {
  type = list(object({
    path    = string
    content = string
  }))
  default = []
}

variable "security_context" {
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

variable "loadbalancer_class_name" {
  type = string
}

variable "storage_class_name" {
  type = string
}