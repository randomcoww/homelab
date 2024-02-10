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

variable "ports" {
  type = object({
    kasm     = number
    sunshine = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "user" {
  type = string
}

variable "uid" {
  type = number
}

variable "ssh_known_hosts" {
  type    = list(string)
  default = []
}

variable "kasm_service_hostname" {
  type = string
}

variable "sunshine_service_hostname" {
  type = string
}

variable "sunshine_service_ip" {
  type = string
}

variable "extra_envs" {
  type    = map(any)
  default = {}
}

variable "resources" {
  type    = any
  default = {}
}

variable "ingress_class_name" {
  type = string
}

variable "nginx_ingress_annotations" {
  type = map(string)
}

variable "volume_claim_size" {
  type = string
}

variable "storage_class" {
  type = string
}

variable "storage_access_modes" {
  type = list(string)
  default = [
    "ReadWriteOnce",
  ]
}