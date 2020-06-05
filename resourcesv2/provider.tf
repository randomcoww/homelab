terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "resources-012-master.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}