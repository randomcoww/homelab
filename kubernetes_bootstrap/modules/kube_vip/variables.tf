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
    kube_vip = string
  })
}

variable "ports" {
  type = object({
    apiserver = number
  })
}

variable "affinity" {
  type    = any
  default = {}
}

variable "bgp_as" {
  type = number
}

variable "bgp_peeras" {
  type = number
}

variable "bgp_neighbor_ips" {
  type = list(string)
}

variable "apiserver_ip" {
  type = string
}