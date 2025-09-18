variable "butane_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "kubelet_port" {
  type = number
}

variable "host_netnum" {
  type = number
}

variable "cni_bridge_interface_name" {
  type = string
}

variable "node_bootstrap_user" {
  type = string
}

variable "cluster_domain" {
  type = string
}

variable "apiserver_endpoint" {
  type = string
}

variable "node_prefix" {
  type = string
}

variable "cluster_dns_ip" {
  type = string
}

variable "config_base_path" {
  type    = string
  default = "/var/lib"
}

variable "kubelet_root_path" {
  type = string
}

variable "static_pod_path" {
  type = string
}

variable "container_storage_path" {
  type = string
}

variable "cni_bin_path" {
  type = string
}

variable "graceful_shutdown_delay" {
  type = number
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "internal_registries" {
  type = list(object({
    prefix   = string
    location = string
  }))
}