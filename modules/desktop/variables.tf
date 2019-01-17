variable "default_user" {
  type = "string"
}

variable "password" {
  type = "string"
}

## desktop
variable "desktop_hosts" {
  type = "list"
}

variable "desktop_ips" {
  type = "list"
}

variable "desktop_if" {
  type = "string"
}

variable "desktop_netmask" {
  type = "string"
}

variable "br_if" {
  type    = "string"
  default = "br0"
}

variable "br_ip" {
  type    = "string"
  default = "169.254.169.254"
}

variable "br_netmask" {
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
