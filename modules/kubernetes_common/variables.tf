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

variable "etcd_cluster_endpoints" {
  type = list(string)
}

variable "ports" {
  type = map(string)
  default = {
    apiserver          = 58081
    controller_manager = 50252
    scheduler          = 50251
    kubelet            = 50250
  }
}

variable "container_images" {
  type = map(string)
  default = {
    kube_apiserver          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
    kube_controller_manager = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
    kube_scheduler          = "ghcr.io/randomcoww/kubernetes:kube-master-v1.22.4"
    kube_addons_manager     = "ghcr.io/randomcoww/kubernetes-addon-manager:master"
  }
}