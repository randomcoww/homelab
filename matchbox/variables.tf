variable "matchbox_http_endpoint" {
  type        = "string"
  description = "Matchbox HTTP read-only endpoint (e.g. http://matchbox.example.com:8080)"
}

variable "matchbox_rpc_endpoint" {
  type        = "string"
  description = "Matchbox gRPC API endpoint, without the protocol (e.g. matchbox.example.com:8081)"
}

variable "container_linux_version" {
  type        = "string"
}

variable "hyperkube_image" {
  type        = "string"
}

variable "default_user" {
  type        = "string"
}

variable "matchbox_url" {
  type        = "string"
}

variable "cluster_cidr" {
  type        = "string"
}

variable "cluster_dns_ip" {
  type        = "string"
}

variable "cluster_service_ip" {
  type        = "string"
}

variable "cluster_name" {
  type        = "string"
}

variable "cluster_domain" {
  type        = "string"
}

variable "vip_matchbox" {
  type        = "string"
}

variable "vip_controller" {
  type        = "string"
}
