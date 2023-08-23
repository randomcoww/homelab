provider "helm" {
  kubernetes {
  }
}

provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare.api_token
}