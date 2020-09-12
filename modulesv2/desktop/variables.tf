variable "client_password" {
  type = string
}

variable "domains" {
  type = map(string)
}

variable "swap_device" {
  type = string
}

variable "hosts" {
  type = any
}

variable "templates" {
  type = list(string)
}