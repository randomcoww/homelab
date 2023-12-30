data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket = local.cluster_resources.bucket
    key    = local.cluster_resources.state
    region = local.aws_region
  }
}