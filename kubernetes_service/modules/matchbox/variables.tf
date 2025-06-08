variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "release" {
  type = string
}

variable "affinity" {
  type    = any
  default = {}
}

variable "replicas" {
  type    = number
  default = 1
}

variable "images" {
  type = object({
    matchbox  = string
    syncthing = string
  })
}

variable "ports" {
  type = object({
    matchbox     = number
    matchbox_api = number
  })
}

variable "api_service_ip" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "loadbalancer_class_name" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}