variable "user" {
  type = string
}

variable "mtu" {
  type = number
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

variable "controller_templates" {
  type = list(string)
}

variable "worker_templates" {
  type = list(string)
}

variable "s3_backup_aws_region" {
  type = string
}

variable "s3_etcd_backup_bucket" {
  type = string
}