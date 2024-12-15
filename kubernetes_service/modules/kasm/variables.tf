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
    kasm = string
  })
}

variable "kasm_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "kasm_resources" {
  type    = any
  default = {}
}

variable "kasm_security_context" {
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

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "kasm_extra_volume_mounts" {
  type    = any
  default = []
}

variable "kasm_extra_volumes" {
  type    = any
  default = []
}