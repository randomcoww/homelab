variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "release" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "ports" {
  type = object({
    apiserver = number
  })
}

variable "loadbalancer_class_name" {
  type = string
}