terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "helm_client-22.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}