terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "minio_bootstrap-24.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}