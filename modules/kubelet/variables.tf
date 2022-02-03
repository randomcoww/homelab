variable "container_images" {
  type = map(string)
}

variable "network_prefix" {
  type    = string
  default = null
}

variable "host_netnum" {
  type    = number
  default = null
}

variable "static_pod_manifest_path" {
  type = string
}