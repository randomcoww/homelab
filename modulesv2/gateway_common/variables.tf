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

variable "hosts" {
  type = any
}

variable "templates" {
  type = list(string)
}

variable "addon_templates" {
  type = map(string)
}