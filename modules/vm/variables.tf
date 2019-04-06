variable "default_user" {
  type = "string"
}

variable "password" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

## vm
variable "vm_hosts" {
  type = "list"
}

variable "vm_store_ips" {
  type = "list"
}

variable "vm_store_if" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "vm_ll_if" {
  type    = "string"
  default = "br0"
}

variable "vm_ll_ip" {
  type = "string"
}

variable "ll_netmask" {
  type = "string"
}

variable "mtu" {
  type = "string"
}

## images
variable "container_linux_image_path" {
  type = "string"
}

variable "container_linux_base_url" {
  type = "string"
}

variable "container_linux_version" {
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
