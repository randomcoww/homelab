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
    user  = string
    token = string
  })
}

variable "tailscale" {
  type = object({
    oauth_client_id     = string
    oauth_client_secret = string
  })
}