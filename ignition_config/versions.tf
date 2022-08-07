terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "resources-22-master.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "0.9.2"
    }
    ssh = {
      source = "github.com/randomcoww/ssh"
    }
  }
}