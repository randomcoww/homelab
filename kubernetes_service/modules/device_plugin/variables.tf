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
    device_plugin = string
  })
}

variable "args" {
  type = list(string)
}