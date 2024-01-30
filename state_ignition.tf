data "terraform_remote_state" "ign" {
  backend = "s3"
  config = {
    bucket = "randomcoww-tfstate"
    key    = "ignition-24.tfstate"
    region = local.aws_region
  }
}