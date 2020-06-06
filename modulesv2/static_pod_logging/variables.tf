variable "services" {
  type = any
}

variable "container_images" {
  type = map(string)
}

variable "static_pod_logging_hosts" {
  type = any
}

variable "static_pod_logging_templates" {
  type = list(string)
}

variable "addon_templates" {
  type = map(string)
}