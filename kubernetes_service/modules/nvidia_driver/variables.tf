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
    nvidia_driver = string
  })
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}
