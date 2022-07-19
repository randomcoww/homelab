variable "cluster_name" {
  type = string
}

variable "ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "node_labels" {
  type = map(string)
}

variable "node_taints" {
  type = any
}

variable "container_storage_path" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}

variable "cni_bridge_interface_name" {
  type = string
}

variable "cluster_domain" {
  type = string
}

variable "apiserver_endpoint" {
  type = string
}

variable "cluster_dns_ip" {
  type = string
}

variable "kubelet_port" {
  type = number
}