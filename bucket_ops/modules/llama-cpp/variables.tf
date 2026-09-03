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

variable "image_volumes" {
  type = map(object({
    image = string
    file  = string
  }))
}

variable "service_port" {
  type = number
}

variable "api_keys" {
  type    = list(string)
  default = []
}

variable "extra_envs" {
  type    = any
  default = {}
}

variable "resources" {
  type    = any
  default = {}
}

variable "gpu_resource_claim_ref" {
  type = map(string)
}