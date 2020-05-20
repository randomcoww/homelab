
variable "pxe_ignition_params" {
  type = any
}

variable "local_ignition_params" {
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