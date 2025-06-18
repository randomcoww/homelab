terraform {
  backend "s3" {
    bucket                      = "terraform"
    key                         = "state/kubernetes_service-0.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.0"
    }
    minio = {
      source  = "aminueza/minio"
      version = "3.5.2"
    }
  }
}