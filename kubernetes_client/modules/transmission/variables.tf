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

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    transmission = string
    wireguard    = string
  })
}

variable "wireguard_config" {
  type = string
}

variable "torrent_done_script" {
  type = string
}

variable "transmission_settings" {
  type = map(string)
}

variable "transmission_extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "blocklist_update_schedule" {
  type    = string
  default = "0 0 * * *"
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

variable "resources" {
  type    = map(any)
  default = {}
}