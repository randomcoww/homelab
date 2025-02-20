variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "ports" {
  type = object({
    metrics = number
  })
}

variable "helm_template" {
  type = object({
    repository = string
    chart      = string
    version    = string
  })
}

variable "replicas" {
  type    = number
  default = 2
}

variable "images" {
  type = object({
    etcd         = string
    external_dns = string
  })
}

variable "service_cluster_ip" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "servers" {
  type    = any
  default = []
}

variable "loadbalancer_class_name" {
  type = string
}