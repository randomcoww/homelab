variable "matchbox_http_endpoint" {
  type        = "string"
  description = "Matchbox HTTP read-only endpoint (e.g. http://matchbox.example.com:8080)"
}

variable "matchbox_rpc_endpoint" {
  type        = "string"
  description = "Matchbox gRPC API endpoint, without the protocol (e.g. matchbox.example.com:8081)"
}

variable "ssh_authorized_key" {
  type        = "string"
}

variable "hyperkube_image" {
  type        = "string"
}

variable "default_user" {
  type        = "string"
}

variable "cluster_dns_ip" {
  type        = "string"
}

variable "cluster_domain" {
  type        = "string"
}

variable "gateway_ip" {
  type        = "string"
}

variable "dns_ip" {
  type        = "string"
}

variable "flannel_conf" {
  type        = "string"
}

variable "cni_conf" {
  type        = "string"
}

variable "kubeconfig_local" {
  type        = "string"
}
