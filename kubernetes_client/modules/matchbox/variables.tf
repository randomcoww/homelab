variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
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
    matchbox       = number
    matchbox_api   = number
    syncthing_peer = number
  })
}

variable "service_ip" {
  type = string
}

variable "service_hostname" {
  type = string
}

variable "cluster_service_endpoint" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}