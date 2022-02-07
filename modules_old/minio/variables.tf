variable "hostname" {
  type = string
}

variable "minio_container_image" {
  type = string
}

variable "minio_port" {
  type = number
}

variable "minio_console_port" {
  type = number
}

variable "minio_credentials" {
  type = object({
    access_key_id     = string
    secret_access_key = string
  })
}

variable "volume_paths" {
  type    = list(string)
  default = []
}

variable "static_pod_manifest_path" {
  type = string
}