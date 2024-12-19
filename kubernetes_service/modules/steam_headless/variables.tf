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
    steam = string
  })
}

variable "steam_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "steam_resources" {
  type    = any
  default = {}
}

variable "steam_security_context" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "vnc_hostname" {
  type = string
}

variable "sunshine_hostname" {
  type = string
}

variable "sunshine_ip" {
  type = string
}

variable "sunshine_admin_hostname" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "steam_extra_volume_mounts" {
  type    = any
  default = []
}

variable "steam_extra_volumes" {
  type    = any
  default = []
}

variable "loadbalancer_class_name" {
  type = string
}

variable "storage_class_name" {
  type = string
}