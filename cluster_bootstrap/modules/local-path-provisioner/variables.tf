variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "timeout" {
  type = number
}

variable "replicas" {
  type    = number
  default = 2
}

variable "volume_paths" {
  type = list(string)
}