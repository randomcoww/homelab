locals {
  matchbox_endpoint    = "https://${local.services.matchbox.ip}:${local.service_ports.matchbox}"
  image_store_endpoint = "https://${local.services.minio.ip}:${local.service_ports.minio}/data-boot"
}

provider "matchbox" {
  endpoint    = "${local.services.matchbox_api.ip}:${local.service_ports.matchbox_api}"
  client_cert = data.terraform_remote_state.client.outputs.matchbox_client.cert_pem
  client_key  = data.terraform_remote_state.client.outputs.matchbox_client.private_key_pem
  ca          = data.terraform_remote_state.client.outputs.matchbox_client.ca_cert_pem
}