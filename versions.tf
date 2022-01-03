terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "resources-015-master.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "0.9.1"
    }
    matchbox = {
      source  = "poseidon/matchbox"
      version = "0.5.0"
    }
    libvirt = {
      source = "github.com/randomcoww/libvirt"
    }
  }
}