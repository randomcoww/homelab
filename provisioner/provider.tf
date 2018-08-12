terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "provisioner.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}