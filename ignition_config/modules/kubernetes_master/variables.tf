variable "cluster_name" {
  type = string
}

variable "ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "etcd_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "service_account" {
  type = object({
    algorithm       = string
    private_key_pem = string
    public_key_pem  = string
  })
}

variable "etcd_cluster_members" {
  type = map(string)
}

variable "apiserver_listen_ips" {
  type = list(string)
}

variable "cluster_apiserver_endpoint" {
  type = string
}

variable "cluster_members" {
  type = map(string)
}

variable "static_pod_manifest_path" {
  type = string
}

variable "container_images" {
  type = map(string)
}

variable "kubernetes_service_prefix" {
  type = string
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "apiserver_port" {
  type = number
}

variable "apiserver_ha_port" {
  type = number
}

variable "etcd_client_port" {
  type = number
}

variable "controller_manager_port" {
  type = number
}

variable "scheduler_port" {
  type = number
}

variable "sync_interface_name" {
  type = string
}

variable "apiserver_interface_name" {
  type = string
}

variable "apiserver_vip" {
  type = string
}

variable "haproxy_config_path" {
  type    = string
  default = "/etc/haproxy/haproxy.cfg.d"
}

variable "keepalived_config_path" {
  type    = string
  default = "/etc/keepalived/keepalived.conf.d"
}