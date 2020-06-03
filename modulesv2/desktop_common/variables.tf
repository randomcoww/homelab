variable "user" {
  type = string
}

variable "password" {
  type = string
}

variable "mtu" {
  type = number
}

variable "networks" {
  type = any
}

variable "domains" {
  type = map(string)
}

variable "desktop_hosts" {
  type = any
}

variable "desktop_templates" {
  type = list(string)
}