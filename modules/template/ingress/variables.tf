variable "name" {
  type = string
}

variable "domains" {
  type = map(string)
}

variable "secrets" {
  type = any
}

variable "hosts" {
  type = any
}