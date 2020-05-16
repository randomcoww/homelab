variable "controller_params" {
  type = any
}

variable "gateway_params" {
  type = any
}

variable "worker_params" {
  type = any
}

variable "kvm_params" {
  type = any
}

variable "desktop_params" {
  type = any
}

variable "test_params" {
  type = any
}

variable "services" {
  type = any
}

variable "renderer" {
  type = map(string)
}

variable "kernel_image" {
  type = string
}

variable "initrd_images" {
  type = list(string)
}

variable "kernel_params" {
  type = list(string)
}