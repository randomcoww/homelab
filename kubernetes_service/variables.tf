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
    user               = string
    arc_runners_token  = string
    renovate_bot_token = string
  })
}