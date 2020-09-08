variable "user" {
  type = string
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

variable "templates" {
  type = list(string)
}