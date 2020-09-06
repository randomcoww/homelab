variable "client_password" {
  type = string
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