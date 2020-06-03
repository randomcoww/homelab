variable "user" {
  type = string
}

variable "mtu" {
  type = number
}

variable "networks" {
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

variable "test_hosts" {
  type = any
}

variable "test_templates" {
  type = list(string)
}
