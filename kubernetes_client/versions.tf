terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "kubernetes_client-24.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    minio = {
      source = "aminueza/minio"
    }
  }
}