provider "matchbox" {
  endpoint    = local.matchbox_api_endpoint
  client_cert = data.terraform_remote_state.bootstrap-server.outputs.matchbox.client_cert.cert_pem
  client_key  = data.terraform_remote_state.bootstrap-server.outputs.matchbox.client_cert.private_key_pem
  ca          = data.terraform_remote_state.bootstrap-server.outputs.matchbox.ca.cert_pem
}