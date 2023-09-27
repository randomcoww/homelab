provider "aws" {
  region = local.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}