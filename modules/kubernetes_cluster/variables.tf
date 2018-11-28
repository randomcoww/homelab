## user
variable "default_user" {
  type = "string"
}

variable "ssh_ca_public_key" {
  type = "string"
}

## controller host
variable "controller_hosts" {
  type = "list"
}

variable "controller_ips" {
  type = "list"
}

variable "controller_macs" {
  type = "list"
}

variable "controller_if" {
  type = "string"
}

## worker host
variable "worker_hosts" {
  type = "list"
}

variable "worker_macs" {
  type = "list"
}

## images
variable "container_linux_base_url" {
  type    = "string"
}

variable "container_linux_version" {
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

variable "cni_plugins_image" {
  type = "string"
}

## kubernetes
variable "cluster_cidr" {
  type    = "string"
  default = "10.244.0.0/16"
}

variable "cluster_dns_ip" {
  type    = "string"
  default = "10.96.0.10"
}

variable "cluster_service_ip" {
  type    = "string"
  default = "10.96.0.1"
}

variable "cluster_ip_range" {
  type    = "string"
  default = "10.96.0.0/12"
}

variable "cluster_name" {
  type = "string"
}

variable "cluster_domain" {
  type    = "string"
  default = "cluster.local"
}

variable "kubelet_path" {
  type    = "string"
  default = "/var/lib/kubelet"
}

variable "etcd_path" {
  type    = "string"
  default = "/var/lib/etcd"
}

variable "etcd_cluster_token" {
  type = "string"
}

## ports
variable "etcd_client_port" {
  type    = "string"
  default = "52379"
}

variable "etcd_peer_port" {
  type    = "string"
  default = "52380"
}

variable "apiserver_secure_port" {
  type = "string"
}

variable "matchbox_http_port" {
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

## ip ranges
variable "netmask" {
  type = "string"
}

## etcd net mount path
variable "etcd_mount_path" {
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
