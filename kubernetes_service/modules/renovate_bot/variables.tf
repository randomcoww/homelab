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
    renovate_bot = string
  })
}

variable "renovate_config" {
  type = any
}

variable "extra_envs" {
  type = list(object({
    name  = string
    value = any
  }))
  default = []
}

variable "cron" {
  type    = string
  default = "@hourly"
}

variable "affinity" {
  type    = any
  default = {}
}