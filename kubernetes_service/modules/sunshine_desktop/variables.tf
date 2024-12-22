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
  })
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

variable "user" {
  type = string
}

variable "uid" {
  type = number
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

variable "loadbalancer_class_name" {
  type = string
}

variable "storage_class_name" {
  type = string
}