variable "default_user" {
  type = "string"
}

## images
variable "container_linux_version" {
  type = "string"
}

variable "fedora_live_version" {
  type = "string"
}

variable "hyperkube_image" {
  type = "string"
}

variable "keepalived_image" {
  type = "string"
}

variable "kube_apiserver_image" {
  type = "string"
}

variable "kube_controller_manager_image" {
  type = "string"
}

variable "kube_scheduler_image" {
  type = "string"
}

variable "kube_proxy_image" {
  type = "string"
}

variable "etcd_image" {
  type = "string"
}

variable "flannel_image" {
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

## kubernetes
variable "cluster_cidr" {
  type = "string"
}

variable "cluster_dns_ip" {
  type = "string"
}

variable "cluster_service_ip" {
  type = "string"
}

variable "cluster_ip_range" {
  type = "string"
}

variable "cluster_name" {
  type = "string"
}

variable "cluster_domain" {
  type = "string"
}

variable "kubernetes_path" {
  type = "string"
}

variable "etcd_client_port" {
  type = "string"
}

variable "apiserver_secure_port" {
  type = "string"
}

variable "matchbox_rpc_port" {
  type = "string"
}

variable "matchbox_http_port" {
  type = "string"
}

## vip
variable "controller_vip" {
  type = "string"
}

variable "gateway_vip" {
  type = "string"
}

variable "nfs_vip" {
  type = "string"
}

variable "matchbox_vip" {
  type = "string"
}

variable "dns_vip" {
  type = "string"
}

variable "lan_netmask" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "backup_dns_ip" {
  type = "string"
}

variable "lan_gateway_vip" {
  type = "string"
}

## ip ranges
variable "lan_ip_range" {
  type = "string"
}

variable "store_ip_range" {
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

## etcd
variable "etcd_initial_cluster" {
  type = "string"
}

variable "etcd_cluster_token" {
  type = "string"
}
