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

variable "store_lan_ips" {
  type = "list"
}

variable "store_store_ips" {
  type = "list"
}

variable "store_lan_if" {
  type = "string"
}

variable "store_store_if" {
  type = "string"
}

## images
variable "hyperkube_image" {
  type = "string"
}

## ip ranges
variable "lan_netmask" {
  type = "string"
}

variable "store_netmask" {
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
