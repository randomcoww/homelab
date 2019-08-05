variable "default_user" {
  type = "string"
}

variable "password" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

variable "kubelet_path" {
  type    = "string"
  default = "/var/lib/kubelet"
}

## vm
variable "vm_hosts" {
  type = "list"
}

variable "desktop_hosts" {
  type = "list"
}

variable "vm_store_ips" {
  type = "list"
}

variable "vm_store_ifs" {
  type = "list"
}

variable "store_netmask" {
  type = "string"
}

variable "ll_if" {
  type    = "string"
  default = "br0"
}

variable "ll_ip" {
  type = "string"
}

variable "ll_netmask" {
  type = "string"
}

variable "vm_lan_if" {
  type    = "string"
  default = "v90"
}

variable "vm_sync_if" {
  type    = "string"
  default = "v60"
}

variable "vm_wan_if" {
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

## Static pod manifest path
variable "matchbox_vip" {
  type = "string"
}

variable "matchbox_http_port" {
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
