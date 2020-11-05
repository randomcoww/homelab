variable "user" {
  type = string
}

variable "domains" {
  type = map(string)
}

variable "ssh_client_public_key" {
  type    = string
  default = ""
}

variable "server_hosts" {
  type = any
}

variable "client_hosts" {
  type = any
}