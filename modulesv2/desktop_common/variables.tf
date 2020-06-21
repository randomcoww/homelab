variable "user" {
  type = string
}

variable "password" {
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