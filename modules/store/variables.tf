variable "default_user" {
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

variable "mtu" {
  type = "string"
}

## images
variable "hyperkube_image" {
  type = "string"
}

## ip ranges
variable "netmask" {
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
