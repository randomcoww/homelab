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
    flannel            = string
    flannel_cni_plugin = string
  })
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "cni_version" {
  type = string
}