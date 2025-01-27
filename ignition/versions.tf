terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "ignition-24.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "0.13.0"
    }
  }
}