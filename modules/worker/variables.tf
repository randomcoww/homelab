variable "container_images" {
  type = map(string)
}

variable "common_certs" {
  type = any
}

variable "apiserver_ip" {
  type = string
}

variable "apiserver_port" {
  type = number
}

variable "kubelet_port" {
  type = number
}

variable "kubernetes_cluster_name" {
  type = string
}

variable "kubernetes_pod_network_prefix" {
  type = string
}

variable "kubernetes_cluster_dns_netnum" {
  type = number
}

variable "kubelet_node_labels" {
  type = map(string)
}

variable "kubernetes_cluster_domain" {
  type = string
}

variable "static_pod_manifest_path" {
  type    = string
  default = "/var/lib/kubelet/manifests"
}