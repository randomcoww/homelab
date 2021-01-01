variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "networks" {
  type = any
}

variable "services" {
  type = any
}

variable "domains" {
  type = map(string)
}

variable "container_images" {
  type = map(string)
}

variable "controller_hosts" {
  type = any
}

variable "worker_hosts" {
  type = any
}

variable "s3_etcd_backup_bucket" {
  type = string
}