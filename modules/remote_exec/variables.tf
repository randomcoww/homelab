variable "host" {
  type = string
}

variable "command" {
  type = list(string)
}

variable "triggers_replace" {
  type    = map(string)
  default = {}
}