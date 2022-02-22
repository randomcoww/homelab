variable "resource_name" {
  type = string
}

variable "resource_namespace" {
  type    = string
  default = "default"
}

variable "replica_count" {
  type = number
}

variable "sync_data_path" {
  type = string
}