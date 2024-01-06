data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket = "randomcoww-tfstate"
    key    = "cluster_resources-23.tfstate"
    region = local.aws_region
  }
}