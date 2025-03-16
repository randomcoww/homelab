variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "replicas" {
  type    = number
  default = 3
}

variable "images" {
  type = object({
    keydb = string
  })
}

variable "ports" {
  type = object({
    keydb = number
  })
}

variable "extra_configs" {
  type    = string
  default = ""
}

variable "volume_claim_templates" {
  type    = any
  default = []
}

variable "extra_volumes" {
  type    = any
  default = []
}

variable "extra_volume_mounts" {
  type    = any
  default = []
}