variable "letsencrypt_username" {
  type = string
}

variable "cloudflare" {
  type = object({
    api_token  = string
    account_id = string
  })
}

variable "tailscale" {
  type = object({
    oauth_client_id     = string
    oauth_client_secret = string
  })
}