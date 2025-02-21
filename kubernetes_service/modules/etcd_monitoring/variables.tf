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

variable "ports" {
  type = object({
    etcd_metrics = number
  })
}