variable "user" {
  type = string
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