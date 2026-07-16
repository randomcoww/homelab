variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type    = string
  default = "0.1.0"
}

variable "replicas" {
  type    = number
  default = 4
}

variable "images" {
  type = object({
    minio = object({
      repository = string
      tag        = string
    })
  })
}

variable "root_user" {
  type = object({
    id     = string
    secret = string
  })
}

variable "cluster_domain" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "service_port" {
  type = number
}

variable "timeout" {
  type = number
}

variable "service_hostname" {
  type = string
}

variable "service_ip" {
  type = string
}

variable "cluster_service_ip" {
  type = string
}