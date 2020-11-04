terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "resources-013beta-master.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
  required_version = ">= 0.13"
}