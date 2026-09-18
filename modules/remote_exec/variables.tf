variable "host" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "command" {
  type = list(string)
}

variable "triggers_replace" {
  type    = list(any)
  default = []
}