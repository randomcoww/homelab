terraform {
  backend "s3" {
    bucket                      = "terraform"
    key                         = "state/s3_resources-0.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.38.1"
    }
    tls = {
      source  = "opentofu/tls"
      version = "4.3.0"
    }
    random = {
      source  = "opentofu/random"
      version = "3.9.0"
    }
    kubernetes = {
      source  = "opentofu/kubernetes"
      version = "3.2.1"
    }
    helm = {
      source  = "opentofu/helm"
      version = "3.2.0"
    }
    ct = {
      source  = "coreos/ct"
      version = "0.14.0"
    }
  }
}