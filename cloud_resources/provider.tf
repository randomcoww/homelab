provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  scopes = [
    "dns",
    "policy_file",
    "oauth_keys",
    # create oauth key with these scopes for k8s-operator
    "devices:core",
    "auth_keys",
    "services",
  ]
}