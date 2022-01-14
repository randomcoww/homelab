variable "users" {
  type = any
}

variable "hostname" {
  type = string
}

variable "container_storage_path" {
  type    = string
  default = "/var/lib/containers/storage"
}