variable "default_user" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

variable "internal_domain" {
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

variable "provisioner_sync_ips" {
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

variable "provisioner_vwan_if" {
  type = "string"
}

variable "provisioner_sync_if" {
  type = "string"
}

## send this MTU via DHCP
variable "mtu" {
  type = "string"
}

variable "kea_ha_roles" {
  type = "list"
}

## images
variable "hyperkube_image" {
  type = "string"
}

variable "keepalived_image" {
  type = "string"
}

variable "unbound_image" {
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

variable "syncthing_image" {
  type = "string"
}

variable "conntrack_image" {
  type = "string"
}

## ports
variable "matchbox_http_port" {
  type = "string"
}

variable "matchbox_rpc_port" {
  type = "string"
}

variable "kea_peer_port" {
  type    = "string"
  default = "58082"
}

variable "syncthing_peer_port" {
  type    = "string"
  default = "22000"
}

## vip
variable "lan_gateway_vip" {
  type = "string"
}

variable "store_gateway_vip" {
  type = "string"
}

variable "recursive_dns_vip" {
  type = "string"
}

variable "internal_dns_vip" {
  type = "string"
}

variable "matchbox_vip" {
  type = "string"
}

variable "public_dns_ip" {
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

variable "sync_ip_range" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "sync_netmask" {
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
variable "kubelet_path" {
  type    = "string"
  default = "/var/lib/kubelet"
}

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
