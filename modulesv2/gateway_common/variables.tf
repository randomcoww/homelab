variable "user" {
  type = string
}

variable "mtu" {
  type = number
}

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

variable "gateway_hosts" {
  type = any
}

variable "gateway_templates" {
  type = list(string)
}

variable "addon_templates" {
  type = map(string)
}