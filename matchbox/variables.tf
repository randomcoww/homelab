variable "default_user" {
  type = "string"
}

variable "domain_name" {
  type = "string"
}


## hosts

## controller
variable "controller_hosts" {
  type = "list"
}

variable "controller_ips" {
  type = "list"
}

variable "controller_macs" {
  type = "list"
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

## worker
variable "worker_hosts" {
  type = "list"
}

variable "worker_macs" {
  type = "list"
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

variable "etcd_peer_port" {
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

variable "dhcp_relay_port" {
  type = "string"
}

## vip
variable "controller_vip" {
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

variable "lan_gateway_vip" {
  type = "string"
}

variable "store_gateway_vip" {
  type = "string"
}

variable "backup_dns_ip" {
  type = "string"
}

variable "lan_netmask" {
  type = "string"
}

variable "store_netmask" {
  type = "string"
}

variable "remote_provision_url" {
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

variable "etcd_cluster_token" {
  type = "string"
}

## general paths
variable "certs_path" {
  type = "string"
}

variable "base_mount_path" {
  type = "string"
}
