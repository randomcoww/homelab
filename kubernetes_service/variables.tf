variable "smtp" {
  type = object({
    host     = string
    port     = string
    username = string
    password = string
  })
}

variable "alpaca" {
  type = object({
    api_key_id     = string
    api_secret_key = string
    api_base_url   = string
  })
}