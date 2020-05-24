variable "user" {
  type = string
}

variable "ssh_client_public_key" {
  type = string
  default = ""
}

variable "ssh_hosts" {
  type = any
}

variable "ssh_templates" {
  type = list(string)
}