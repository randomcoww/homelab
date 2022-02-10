variable "template_params" {
  type = any
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

variable "metallb_network_prefix" {
  type = string
}

variable "container_images" {
  type = map(string)
}