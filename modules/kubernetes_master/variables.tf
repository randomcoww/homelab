variable "ca" {
  type = map(string)
}

variable "etcd_ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "etcd_certs" {
  type = any
}

variable "template_params" {
  type = any
}

variable "addon_manifests_path" {
  type = string
}

variable "static_pod_manifest_path" {
  type = string
}