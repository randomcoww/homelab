variable "users" {
  type = any
}

variable "services" {
  type = any
}

variable "container_images" {
  type = map(string)
}

variable "hosts" {
  type = any
}

variable "local_timezone" {
  type = string
}