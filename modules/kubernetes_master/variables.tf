variable "cluster_name" {
  type = string
}

variable "ca" {
  type = map(string)
}

variable "etcd_ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "etcd_certs" {
  type = any
}

variable "encryption_config_secret" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}

variable "etcd_cluster_endpoints" {
  type = list(string)
}

variable "service_network_prefix" {
  type = string
}

variable "pod_network_prefix" {
  type = string
}

variable "apiserver_cert_ips" {
  type = list(string)
}

variable "apiserver_port" {
  type = number
}

variable "apiserver_internal_port" {
  type = number
}

variable "apiserver_members" {
  type = list(object({
    name = string
    ip   = string
  }))
}

variable "controller_manager_port" {
  type = number
}

variable "scheduler_port" {
  type = number
}

variable "container_images" {
  type = map(string)
}

variable "haproxy_config_path" {
  type    = string
  default = "/etc/haproxy/haproxy.cfg.d"
}