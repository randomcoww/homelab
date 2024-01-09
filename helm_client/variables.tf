variable "letsencrypt" {
  type = object({
    email = string
  })
}

variable "alpaca" {
  type = object({
    api_key_id     = string
    api_secret_key = string
    api_base_url   = string
  })
}