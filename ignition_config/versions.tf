terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "ignition_config-23.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "0.11.0"
    }
    ssh = {
      source = "github.com/randomcoww/ssh"
    }
  }
}