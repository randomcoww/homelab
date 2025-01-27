terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "kubernetes_client-24.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    minio = {
      source  = "aminueza/minio"
      version = "3.2.2"
    }
  }
}