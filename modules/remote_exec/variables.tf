variable "host" {
  type = string
}

variable "command" {
  type = list(string)
}

variable "triggers_replace" {
  type    = list(any)
  default = []
}