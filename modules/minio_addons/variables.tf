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

variable "minio_ip" {
  type = string
}

variable "minio_port" {
  type = number
}

variable "minio_console_port" {
  type = number
}

variable "affinity_host_class" {
  type = string
}

variable "volume_paths" {
  type    = list(string)
  default = []
}

variable "container_images" {
  type = map(string)
}