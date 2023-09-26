terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "stateful_resources-23.tfstate"
    region  = "us-west-2"
    encrypt = true
  }

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}