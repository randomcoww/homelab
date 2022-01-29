variable "minio_container_image" {
  type = string
}

variable "minio_port" {
  type = number
}

variable "minio_console_port" {
  type = number
}

variable "volume_paths" {
  type    = list(string)
  default = []
}

variable "static_pod_manifest_path" {
  type    = string
  default = "/var/lib/kubelet/manifests"
}