variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "llama_swap_config" {
  type    = any
  default = {}
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    llama_swap = string
  })
}

variable "models" {
  type = map(object({
    image = string
    file  = string
  }))
}

variable "api_keys" {
  type    = list(string)
  default = []
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "ingress_hostname" {
  type = string
}

variable "gateway_ref" {
  type = any
}