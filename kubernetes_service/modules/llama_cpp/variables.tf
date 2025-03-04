variable "cluster_service_endpoint" {
  type = string
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
    mountpoint = string
    llama_cpp  = string
  })
}

variable "ports" {
  type = object({
    llama_cpp = number
  })
}

variable "resources" {
  type    = any
  default = {}
}

variable "security_context" {
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

variable "s3_endpoint" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "s3_access_key_id" {
  type = string
}

variable "s3_secret_access_key" {
  type = string
}

variable "s3_mount_extra_args" {
  type    = list(string)
  default = []
}