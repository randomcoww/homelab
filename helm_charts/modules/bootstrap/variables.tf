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

variable "kube_kubelet_access_user" {
  type = string
}

variable "kube_node_bootstrap_user" {
  type = string
}