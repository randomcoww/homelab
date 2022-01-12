variable "etcd_container_image" {
  type = string
}

variable "etcd_wrapper_container_image" {
  type = string
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

variable "aws_secret_access_key" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "s3_backup_path" {
  type = string
}

variable "etcd_ca" {
  type = object({
    algorithm       = string
    private_key_pem = string
    cert_pem        = string
  })
}