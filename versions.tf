terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "resources-014-master.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
  required_providers {
    ct = {
      source = "github.com/poseidon/ct"
    }
    matchbox = {
      source = "github.com/poseidon/matchbox"
    }
    libvirt = {
      source = "github.com/randomcoww/libvirt"
    }
  }
}