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

variable "kubelet_client_user" {
  type = string
}

variable "node_bootstrap_user" {
  type = string
}