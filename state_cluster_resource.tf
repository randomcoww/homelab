data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket                      = "terraform"
    key                         = "state/cluster_resources-0.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}