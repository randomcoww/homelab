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
    mountpoint = string
    steamcmd   = string
  })
}

variable "command" {
  type    = list(string)
  default = []
}

variable "tcp_ports" {
  type = map(number)
}

variable "udp_ports" {
  type = map(number)
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

variable "extra_volume_mounts" {
  type    = any
  default = []
}

variable "extra_volumes" {
  type    = any
  default = []
}

variable "service_hostname" {
  type = string
}

variable "steamapp_id" {
  type = number
}

variable "storage_class_name" {
  type = string
}

variable "loadbalancer_class_name" {
  type = string
}

variable "resources" {
  type    = any
  default = {}
}

variable "healthcheck" {
  type    = any
  default = {}
}

variable "security_context" {
  type    = any
  default = {}
}

variable "s3_endpoint" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}