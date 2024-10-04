variable "name" {
  type = string
}

variable "app" {
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
    syncthing = string
  })
}

variable "replicas" {
  type    = number
  default = 1
}

variable "labels" {
  type    = any
  default = {}
}

variable "annotations" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}
variable "tolerations" {
  type    = any
  default = []
}

variable "spec" {
  type    = any
  default = {}
}

variable "template_spec" {
  type    = any
  default = {}
}

variable "sync_data_paths" {
  type = list(string)
}