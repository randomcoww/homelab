provider "aws" {
  region = local.aws_region
}

provider "tailscale" {
  tailnet             = local.domains.tailscale
  oauth_client_id     = var.tailscale.oauth_client_id
  oauth_client_secret = var.tailscale.oauth_client_secret
  scopes              = ["all"]
}