variable "networks" {
  type = any
}

variable "loadbalancer_pools" {
  type = any
}

variable "services" {
  type = any
}

variable "domains" {
  type = map(string)
}

variable "container_images" {
  type = map(string)
}

variable "secrets" {
  type = any
}

variable "internal_tls_hosts" {
  type = any
}

variable "internal_tls_templates" {
  type = list(string)
}

variable "addon_templates" {
  type = map(string)
}