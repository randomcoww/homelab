variable "cluster_name" {
  type = string
}

variable "user" {
  type = string
}

variable "context" {
  type    = string
  default = "default"
}

variable "apiserver_endpoint" {
  type = string
}

variable "ca_cert_pem" {
  type = string
}

variable "client_cert_pem" {
  type = string
}

variable "client_key_pem" {
  type = string
}