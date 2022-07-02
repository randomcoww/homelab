variable "cluster_name" {
  type = string
}

variable "ca" {
  type = map(string)
}

variable "certs" {
  type = any
}

variable "node_labels" {
  type = map(string)
}

variable "node_taints" {
  type = any
}

variable "container_storage_path" {
  type = string
}

# build for https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner
# volumes can be directories but must be bind mounted from elsewhere
variable "local_storage_class_path" {
  type = string
}

variable "local_storage_class_mount_path" {
  type = string
}

variable "local_storage_class_volume_count" {
  type    = number
  default = 10
}
#

variable "static_pod_manifest_path" {
  type = string
}

variable "cni_bridge_interface_name" {
  type = string
}

variable "cluster_domain" {
  type = string
}

variable "apiserver_ip" {
  type = string
}

variable "service_network" {
  type = any
}

variable "pod_network" {
  type = any
}

variable "apiserver_port" {
  type = number
}

variable "kubelet_port" {
  type = number
}