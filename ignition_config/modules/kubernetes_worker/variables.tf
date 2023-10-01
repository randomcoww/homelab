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

variable "node_labels" {
  type = map(string)
}

variable "node_taints" {
  type = any
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

variable "node_ip" {
  type = string
}

variable "cluster_dns_ip" {
  type = string
}

variable "kubelet_port" {
  type = number
}

variable "container_storage_path" {
  type    = string
  default = "/var/lib/containers/storage"
}