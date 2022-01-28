variable "container_images" {
  type = map(string)
}

variable "kubernetes_common_certs" {
  type = any
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
  type = string
}

variable "internal_domain" {
  type = string
}

variable "kubernetes_cluster_name" {
  type = string
}

variable "kubernetes_external_dns_ip" {
  type = string
}

variable "internal_dns_ip" {
  type = string
}

variable "kubernetes_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "static_pod_manifest_path" {
  type = string
}

variable "metallb_network_prefix" {
  type = string
}

variable "metallb_subnet" {
  type = object({
    newbit = number
    netnum = number
  })
}