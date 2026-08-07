variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 1
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    camofox-browser = object({
      repository = string
      tag        = string
    })
  })
}

variable "extra_envs" {
  type    = any
  default = {}
}