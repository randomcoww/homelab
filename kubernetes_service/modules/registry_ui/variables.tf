variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    registry_ui = string
  })
}

variable "service_hostname" {
  type = string
}

variable "registry_url" {
  type = string
}

variable "timezone" {
  type = string
}

variable "event_listener_token" {
  type = string
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "resources" {
  type    = any
  default = {}
}