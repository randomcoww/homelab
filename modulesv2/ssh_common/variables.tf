variable "user" {
  type = string
}

variable "ssh_hosts" {
  type = any
}

variable "ssh_templates" {
  type = list(string)
}