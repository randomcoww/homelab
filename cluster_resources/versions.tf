terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "cluster_resources-23.tfstate"
    region  = "us-west-2"
    encrypt = true
  }

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "0.17.2"
    }
  }
}