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

variable "replicas" {
  type    = number
  default = 1
}

variable "images" {
  type = object({
    kube_vip_cloud_provider = string
  })
}

variable "affinity" {
  type    = any
  default = {}
}

# https://kube-vip.io/docs/usage/cloud-provider/#the-kube-vip-cloud-provider-configmap
variable "ip_pools" {
  type    = map(string)
  default = {}
}