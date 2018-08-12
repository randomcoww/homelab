variable "default_user" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

## live

variable "live_hosts" {
  type = "list"
}

variable "live_macs" {
  type = "list"
}

variable "live_lan_ips" {
  type = "list"
}

variable "live_store_ips" {
  type = "list"
}

variable "live_lan_if" {
  type = "string"
}

variable "live_store_if" {
  type = "string"
}

## images
variable "hyperkube_image" {
  type = "string"
}

variable "fedora_live_version" {
  type = "string"
}

## ports
variable "matchbox_http_port" {
  type = "string"
}

## vip
variable "matchbox_vip" {
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
