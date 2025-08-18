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
    hostapd = string
  })
}

variable "replicas" {
  type = number
}

variable "affinity" {
  type    = any
  default = {}
}

variable "bssid_base" {
  type    = number
  default = 20000000000000
}

variable "config" {
  type = any
}

variable "resources" {
  type    = any
  default = {}
}