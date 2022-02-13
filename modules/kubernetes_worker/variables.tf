variable "ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "template_params" {
  type = any
}

variable "node_labels" {
  type = map(string)
}

variable "register_with_taints" {
  type = map(string)
}

variable "container_storage_path" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}

variable "ports" {
  type = map(string)
}