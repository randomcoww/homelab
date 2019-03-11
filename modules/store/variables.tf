variable "default_user" {
  type = "string"
}

variable "password" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

## store
variable "store_hosts" {
  type = "list"
}

variable "store_ips" {
  type = "list"
}

variable "store_if" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "ll_if" {
  type    = "string"
  default = "br0"
}

variable "ll_ip" {
  type    = "string"
  default = "169.254.169.254"
}

variable "ll_netmask" {
  type    = "string"
  default = "16"
}

variable "mtu" {
  type = "string"
}

## matchbox provisioning access
variable "renderer_endpoint" {
  type = "string"
}

variable "renderer_private_key_pem" {
  type = "string"
}

variable "renderer_cert_pem" {
  type = "string"
}

variable "renderer_ca_pem" {
  type = "string"
}
