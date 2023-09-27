data "terraform_remote_state" "sr" {
  backend = "s3"
  config = {
    bucket = "randomcoww-tfstate"
    key    = local.states.cluster_resources
    region = local.aws_region
  }
}

data "terraform_remote_state" "client" {
  backend = "local"
  config = {
    path = "../client/terraform.tfstate"
  }
}

provider "helm" {
  kubernetes {
    host                   = "https://${local.services.apiserver.ip}:${local.ports.apiserver_ha}"
    client_certificate     = data.terraform_remote_state.client.outputs.kubernetes_admin.cert_pem
    client_key             = data.terraform_remote_state.client.outputs.kubernetes_admin.private_key_pem
    cluster_ca_certificate = data.terraform_remote_state.client.outputs.kubernetes_admin.ca_cert_pem
  }
}