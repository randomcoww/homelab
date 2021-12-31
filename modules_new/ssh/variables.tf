variable "user" {
  type = any
}

variable "server_valid_principals" {
  type = list(string)
}

variable "server_hosts" {
  type = list(string)
  default = []
}

variable "client_hosts" {
  type = list(string)
  default = []
}

variable "client_public_key" {
  type    = string
  default = ""
}