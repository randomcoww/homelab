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
    code_server = string
  })
}

variable "ports" {
  type = object({
    code_server = number
  })
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "home_path" {
  type = string
}

variable "code_server_extra_configs" {
  type = list(object({
    path    = string
    content = string
  }))
  default = []
}

variable "code_server_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "code_server_resources" {
  type    = any
  default = {}
}

variable "code_server_security_context" {
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

variable "code_server_extra_volume_mounts" {
  type    = any
  default = []
}

variable "code_server_extra_volumes" {
  type    = any
  default = []
}