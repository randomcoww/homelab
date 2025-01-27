terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "cluster_resources-23.tfstate"
    region  = "us-west-2"
    encrypt = true
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.51.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.17.2"
    }
  }
}