variable "hostname" {
  type = string
}

variable "container_images" {
  type = map(string)
}

variable "common_certs" {
  type = any
}

variable "network_prefix" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "vip_netnum" {
  type = number
}

variable "apiserver_port" {
  type = number
}

variable "controller_manager_port" {
  type = number
}

variable "scheduler_port" {
  type = number
}

variable "etcd_servers" {
  type = list(string)
}

variable "etcd_client_port" {
  type = number
}

variable "kubernetes_cluster_name" {
  type = string
}

variable "kubernetes_service_network_prefix" {
  type = string
}

variable "kubernetes_pod_network_prefix" {
  type = string
}

variable "encryption_config_secret" {
  type = string
}

variable "kubernetes_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}