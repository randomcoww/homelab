variable "container_images" {
  type = map(string)
}

variable "resource_name" {
  type = string
}

variable "pod_count" {
  type = number
}

variable "allowed_network_prefix" {
  type = string
}

variable "internal_pxeboot_ip" {
  type = string
}

variable "internal_pxeboot_http_port" {
  type = number
}

variable "internal_pxeboot_api_port" {
  type = number
}