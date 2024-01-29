variable "node_ip" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}

variable "container_storage_path" {
  type    = string
  default = "/var/lib/containers/storage"
}