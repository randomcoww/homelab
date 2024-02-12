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
    satisfactory_server = string
  })
}

variable "ports" {
  type = object({
    beacon = number
    game   = number
    query  = number
  })
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

variable "extra_envs" {
  type    = map(string)
  default = {}
}

variable "resources" {
  type    = any
  default = {}
}

variable "config_overrides" {
  type    = map(string)
  default = {}
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