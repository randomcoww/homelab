variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "source_release" {
  type = string
}

variable "replicas" {
  type    = number
  default = 2
}

variable "images" {
  type = object({
    coredns = string
  })
}

variable "service_cluster_ip" {
  type = string
}

variable "servers" {
  type    = any
  default = []
}