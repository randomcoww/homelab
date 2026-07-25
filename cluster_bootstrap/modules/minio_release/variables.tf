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

variable "timeout" {
  type = number
}

variable "replicas" {
  type    = number
  default = 4
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    minio = string
  })
}

variable "root_user" {
  type = object({
    id     = string
    secret = string
  })
}

variable "ca_issuer_name" {
  type = string
}

variable "service_port" {
  type = number
}

variable "service_hostname" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "resources" {
  type    = any
  default = {}
}