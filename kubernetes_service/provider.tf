provider "kubernetes" {
  host                   = "https://${local.services.apiserver.ip}:${local.host_ports.apiserver}"
  client_certificate     = data.terraform_remote_state.client.outputs.kubernetes_client.cert_pem
  client_key             = data.terraform_remote_state.client.outputs.kubernetes_client.private_key_pem
  cluster_ca_certificate = data.terraform_remote_state.client.outputs.kubernetes_client.ca_cert_pem
}

provider "helm" {
  kubernetes = {
    host                   = "https://${local.services.apiserver.ip}:${local.host_ports.apiserver}"
    client_certificate     = data.terraform_remote_state.client.outputs.kubernetes_client.cert_pem
    client_key             = data.terraform_remote_state.client.outputs.kubernetes_client.private_key_pem
    cluster_ca_certificate = data.terraform_remote_state.client.outputs.kubernetes_client.ca_cert_pem
  }
}