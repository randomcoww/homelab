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

variable "kubernetes_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "registry_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "ports" {
  type = object({
    kubelet      = number
    crio_metrics = number
    vlagent      = number
  })
}

variable "host_netnum" {
  type = number
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
  default = "/var/lib/kubernetes"
}

variable "kubelet_root_path" {
  type = string
}

variable "static_pod_path" {
  type = string
}

variable "feature_gates" {
  type = map(bool)
}

variable "container_storage_path" {
  type = string
}

variable "cni_bin_path" {
  type = string
}

variable "cni_config_path" {
  type = string
}

variable "crio_socket" {
  type    = string
  default = "/run/crio/crio.sock"
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

variable "kubelet_bootstrap_user" {
  type    = string
  default = "kubelet-bootstrap"
}