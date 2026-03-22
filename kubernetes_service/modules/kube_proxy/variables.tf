variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "affinity" {
  type    = any
  default = {}
}

variable "images" {
  type = object({
    kube_proxy = string
  })
}

variable "ports" {
  type = object({
    kube_proxy         = number
    kube_proxy_metrics = number
    kube_apiserver     = number
  })
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "kube_apiserver_ip" {
  type = string
}