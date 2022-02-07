variable "ca" {
  type = map(string)
}

variable "peer_ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "template_params" {
  type = any
}

variable "static_pod_manifest_path" {
  type = string
}

variable "container_images" {
  type = map(string)
}