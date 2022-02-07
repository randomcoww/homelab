variable "cluster_name" {
  type = string
}

variable "cluster_domain" {
  type    = string
  default = "cluster.internal"
}

variable "apiserver_vip" {
  type = string
}

variable "apiserver_port" {
  type = number
}

variable "etcd_cluster_endpoints" {
  type = list(string)
}

variable "ports" {
  type = map(string)
  default = {
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
  }
}