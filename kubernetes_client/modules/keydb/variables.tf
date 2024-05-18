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

variable "extra_config" {
  type    = string
  default = ""
}

variable "cluster_service_endpoint" {
  type = string
}