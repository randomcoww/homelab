variable "default_user" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

variable "domain_name" {
  type = "string"
}

## instance
variable "output_path" {
  type = "string"
}

## provisioner
variable "provisioner_hosts" {
  type = "list"
}

variable "provisioner_lan_ips" {
  type = "list"
}

variable "provisioner_store_ips" {
  type = "list"
}

variable "provisioner_lan_if" {
  type = "string"
}

variable "provisioner_store_if" {
  type = "string"
}

variable "provisioner_wan_if" {
  type = "string"
}

## images
variable "hyperkube_image" {
  type = "string"
}

variable "keepalived_image" {
  type = "string"
}

variable "nftables_image" {
  type = "string"
}

variable "kea_image" {
  type = "string"
}

variable "tftpd_image" {
  type = "string"
}

variable "matchbox_image" {
  type = "string"
}

## ports
variable "matchbox_http_port" {
  type = "string"
}

variable "matchbox_rpc_port" {
  type = "string"
}

## vip
variable "lan_gateway_vip" {
  type = "string"
}

variable "store_gateway_vip" {
  type = "string"
}

variable "dns_vip" {
  type = "string"
}

variable "matchbox_vip" {
  type = "string"
}

variable "controller_vip" {
  type = "string"
}

variable "nfs_vip" {
  type = "string"
}

variable "backup_dns_ip" {
  type = "string"
}

## ip ranges
variable "lan_ip_range" {
  type = "string"
}

variable "lan_netmask" {
  type = "string"
}

variable "store_ip_range" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "lan_dhcp_ip_range" {
  type = "string"
}

variable "store_dhcp_ip_range" {
  type = "string"
}

variable "metallb_ip_range" {
  type = "string"
}

## service paths
variable "certs_path" {
  type    = "string"
  default = "/etc/ssl/certs"
}

variable "kea_path" {
  type    = "string"
  default = "/var/lib/kea"
}

variable "matchbox_path" {
  type    = "string"
  default = "/var/lib/matchbox"
}

variable "kea_mount_path" {
  type = "string"
}

variable "matchbox_mount_path" {
  type = "string"
}

## provisioner provisions from github
variable "remote_provision_url" {
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
