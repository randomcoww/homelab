provider "matchbox" {
  endpoint    = local.matchbox_api_endpoint
  client_cert = data.terraform_remote_state.bootstrap-server.outputs.matchbox_client.cert_pem
  client_key  = data.terraform_remote_state.bootstrap-server.outputs.matchbox_client.private_key_pem
  ca          = data.terraform_remote_state.bootstrap-server.outputs.matchbox_ca.cert_pem
}