provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  scopes = [
    "auth_keys",
    "devices:core:read",
    "devices:posture_attributes",
    "dns",
    "policy_file",
  ]
}