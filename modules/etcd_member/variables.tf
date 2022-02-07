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

variable "etcd_container_image" {
  type = string
}

variable "etcd_wrapper_container_image" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}