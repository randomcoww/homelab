variable "desktop_user" {
  type = "string"
}

variable "localhome_path" {
  type    = "string"
  default = "/localhome"
}

variable "password" {
  type = "string"
}

## desktop
variable "desktop_hosts" {
  type = "list"
}

variable "desktop_store_ips" {
  type = "list"
}

variable "desktop_store_if" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "desktop_ll_if" {
  type    = "string"
  default = "br0"
}

variable "desktop_ll_ip" {
  type = "string"
}

variable "ll_netmask" {
  type = "string"
}

variable "desktop_lan_if" {
  type    = "string"
  default = "v90"
}

variable "desktop_sync_if" {
  type    = "string"
  default = "v60"
}

variable "desktop_wan_if" {
  type    = "string"
  default = "v30"
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
