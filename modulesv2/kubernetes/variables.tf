variable "user" {
  type = string
}

variable "ssh_ca_public_key" {
  type = string
}

variable "mtu" {
  type = number
}

variable "networks" {
  type = any
}

variable "services" {
  type = any
}

variable "domains" {
  type = any
}

variable "container_images" {
  type = any
}

variable "controller_hosts" {
  type = any
}

variable "worker_hosts" {
  type = any
}

variable "s3_backup_aws_region" {
  type = string
}

variable "s3_etcd_backup_bucket" {
  type = string
}

variable "kubernetes_cluster_name" {
  type = string
}

variable "renderer" {
  type = map(string)
}