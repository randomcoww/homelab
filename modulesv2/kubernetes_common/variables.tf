variable "aws_region" {
  type = string
}

variable "user" {
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

variable "controller_templates" {
  type = list(string)
}

variable "worker_templates" {
  type = list(string)
}

variable "s3_etcd_backup_bucket" {
  type = string
}

variable "addon_templates" {
  type = map(string)
}