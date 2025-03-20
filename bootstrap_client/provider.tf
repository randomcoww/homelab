locals {
  matchbox_endpoint    = data.terraform_remote_state.bootstrap-server.outputs.matchbox_endpoint
  image_store_endpoint = "${data.terraform_remote_state.bootstrap-server.outputs.matchbox_endpoint}/assets"
}

provider "matchbox" {
  endpoint    = "127.0.0.1:${local.service_ports.matchbox_api}"
  client_cert = data.terraform_remote_state.bootstrap-server.outputs.matchbox.client_cert.cert_pem
  client_key  = data.terraform_remote_state.bootstrap-server.outputs.matchbox.client_cert.private_key_pem
  ca          = data.terraform_remote_state.bootstrap-server.outputs.matchbox.ca.cert_pem
}