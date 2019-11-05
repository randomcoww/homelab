variable "apiserver_vip" {
  type = string
}

variable "namespace" {
  type = string
}

variable "networks" {
  type = any
}

variable "services" {
  type = any
}

variable "domains" {
  type = any
}

variable "container_images" {
  type = any
}

variable "renderer" {
  type = map(string)
}