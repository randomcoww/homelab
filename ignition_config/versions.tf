terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "ignition_config-24.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    ct = {
      source = "poseidon/ct"
    }
  }
}