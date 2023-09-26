data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket = "randomcoww-tfstate"
    key    = local.states.stateful_resources
    region = var.aws_region
  }
}