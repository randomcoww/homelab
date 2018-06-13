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

variable "internal_domain" {
  type        = "string"
}

variable "gateway_ip" {
  type        = "string"
}

variable "dns_ip" {
  type        = "string"
}

variable "controller_ip" {
  type        = "string"
}

variable "matchbox_ip" {
  type        = "string"
}
