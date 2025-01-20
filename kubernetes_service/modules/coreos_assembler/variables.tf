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
    coreos_assembler = string
  })
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}
