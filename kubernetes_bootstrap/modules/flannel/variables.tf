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

variable "ports" {
  type = object({
    healthz = number
  })
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "cni_version" {
  type = string
}

variable "cni_bridge_interface_name" {
  type = string
}

variable "cni_bin_path" {
  type = string
}