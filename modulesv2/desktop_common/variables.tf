variable "user" {
  type = string
}

variable "desktop_user" {
  type = string
}

variable "desktop_password" {
  type = string
}

variable "mtu" {
  type = number
}

variable "domains" {
  type = map(string)
}

variable "hosts" {
  type = any
}

variable "templates" {
  type = list(string)
}