locals {
  matchbox_endpoint     = data.terraform_remote_state.bootstrap-server.outputs.matchbox_endpoint
  matchbox_api_endpoint = "127.0.0.1:${local.service_ports.matchbox_api}"
  image_store_endpoint  = "${data.terraform_remote_state.bootstrap-server.outputs.matchbox_endpoint}/assets"
}

data "terraform_remote_state" "bootstrap-server" {
  backend = "local"
  config = {
    path = "../bootstrap_server/terraform.tfstate"
  }
}