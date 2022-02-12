variable "resource_name" {
  type = string
}

variable "affinity_resource_name" {
  type = string
}

variable "resource_namespace" {
  type    = string
  default = "default"
}

variable "replica_count" {
  type = number
}

variable "matchbox_path" {
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

variable "container_images" {
  type = map(string)
}