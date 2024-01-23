variable "name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "release" {
  type = string
}

variable "kubelet_root_path" {
  type = string
}

variable "images" {
  type = object({
    fuse_device_plugin = string
  })
}