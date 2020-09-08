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

variable "addon_templates" {
  type = map(string)
}