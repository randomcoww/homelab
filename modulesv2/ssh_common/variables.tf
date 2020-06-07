variable "user" {
  type = string
}

variable "networks" {
  type = any
}

variable "domains" {
  type = map(string)
}

variable "ssh_client_public_key" {
  type    = string
  default = ""
}

variable "hosts" {
  type = any
}

variable "templates" {
  type = list(string)
}