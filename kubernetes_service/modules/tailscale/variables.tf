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
    tailscale = string
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "tailscale_auth_key" {
  type = string
}