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

variable "internal_cert_pem" {
  type = string
}

variable "internal_private_key_pem" {
  type = string
}

variable "renderer" {
  type = map(string)
}