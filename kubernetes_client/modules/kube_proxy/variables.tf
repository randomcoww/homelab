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
    kube_proxy = string
  })
}

variable "ports" {
  type = object({
    kube_proxy     = number
    kube_apiserver = number
  })
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "kube_apiserver_ip" {
  type = string
}