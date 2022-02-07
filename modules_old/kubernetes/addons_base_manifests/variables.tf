variable "container_images" {
  type = map(string)
}

variable "apiserver_ip" {
  type = string
}

variable "apiserver_port" {
  type = number
}

variable "kubernetes_pod_network_prefix" {
  type = string
}

variable "kubernetes_service_network_prefix" {
  type = string
}

variable "kubernetes_service_network_dns_netnum" {
  type = number
}

variable "flannel_host_gateway_interface_name" {
  type = string
}

variable "kubernetes_cluster_domain" {
  type    = string
  default = "cluster.local"
}

variable "kubernetes_cluster_name" {
  type = string
}

variable "internal_domain" {
  type = string
}

variable "internal_domain_dns_ip" {
  type = string
}

variable "forwarding_dns_ip" {
  type = string
}

variable "metallb_subnet" {
  type = string
}