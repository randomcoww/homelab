variable "hostname" {
  type = string
}

variable "container_images" {
  type = map(string)
}

variable "common_certs" {
  type = any
}

variable "network_prefix" {
  type = string
}

variable "host_netnum" {
  type = number
}

variable "etcd_hosts" {
  type = list(map(string))
}

variable "etcd_cluster_token" {
  type = string
}

variable "etcd_client_port" {
  type = number
}

variable "etcd_peer_port" {
  type = number
}

variable "aws_access_key_id" {
  type = string
}

variable "aws_access_key_secret" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "s3_backup_path" {
  type = string
}

variable "static_pod_manifest_path" {
  type    = string
  default = "/var/lib/kubelet/manifests"
}

variable "etcd_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}