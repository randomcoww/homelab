variable "resource_name" {
  type = string
}

variable "resource_namespace" {
  type    = string
  default = "default"
}

variable "service_name" {
  type = string
}

variable "replica_count" {
  type = number
}

variable "sync_data_paths" {
  type = list(string)
}

variable "syncthing_peer_port" {
  type    = number
  default = 22000
}