terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "desktop.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}
