variable "ignition_version" {
  type = string
}

variable "fw_mark" {
  type = string
}

variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "kube-system"
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}

variable "front_proxy_ca" {
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

variable "images" {
  type = object({
    apiserver          = string
    controller_manager = string
    scheduler          = string
  })
}

variable "ports" {
  type = object({
    apiserver          = number
    apiserver_backend  = number
    controller_manager = number
    scheduler          = number
    etcd_client        = number
  })
}

variable "members" {
  type = map(string)
}

variable "etcd_members" {
  type = map(string)
}

variable "cluster_apiserver_endpoint" {
  type = string
}

variable "kubelet_client_user" {
  type = string
}

variable "front_proxy_client_user" {
  type = string
}

variable "controller_manager_user" {
  type    = string
  default = "system:kube-controller-manager"
}

variable "scheduler_user" {
  type    = string
  default = "system:kube-scheduler"
}

variable "admin_user" {
  type    = string
  default = "default-admin"
}

variable "kubernetes_service_prefix" {
  type = string
}

variable "kubernetes_pod_prefix" {
  type = string
}

variable "node_ip" {
  type = string
}

variable "apiserver_ip" {
  type = string
}

variable "apiserver_interface_name" {
  type = string
}

variable "cluster_apiserver_ip" {
  type = string
}

variable "config_base_path" {
  type    = string
  default = "/var/lib"
}

variable "static_pod_path" {
  type = string
}

variable "haproxy_path" {
  type = string
}

variable "bird_path" {
  type = string
}

variable "bgp_as" {
  type = number
}

variable "bgp_range_prefix" {
  type = string
}

variable "bgp_local_ip" {
  type = string
}