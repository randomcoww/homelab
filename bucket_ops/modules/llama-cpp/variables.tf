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
    llama-swap = object({
      repository = string
      tag        = string
    })
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
  type    = any
  default = {}
}

variable "service_port" {
  type = number
}

variable "resources" {
  type    = any
  default = {}
}