variable "github" {
  type = object({
    username = string
    token    = string
  })
}

variable "smtp" {
  type = object({
    host     = string
    port     = number
    username = string
    password = string
  })
}