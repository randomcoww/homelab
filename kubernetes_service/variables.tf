variable "smtp" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
  })
}

variable "github" {
  type = object({
    renovate_token = string
  })
}