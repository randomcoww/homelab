terraform {
  backend "s3" {
    bucket  = "randomcoww-tfstate"
    key     = "kubernetes_cluster.tfstate"
    region  = "us-west-2"
    encrypt = true
  }
}