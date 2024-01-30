provider "helm" {
  kubernetes {
    host                   = "https://${local.services.apiserver.ip}:${local.ports.apiserver}"
    client_certificate     = data.terraform_remote_state.client.outputs.kubernetes_admin.cert_pem
    client_key             = data.terraform_remote_state.client.outputs.kubernetes_admin.private_key_pem
    cluster_ca_certificate = data.terraform_remote_state.client.outputs.kubernetes_admin.ca_cert_pem
  }
}

provider "kubernetes" {
  host                   = "https://${local.services.apiserver.ip}:${local.ports.apiserver}"
  client_certificate     = data.terraform_remote_state.client.outputs.kubernetes_admin.cert_pem
  client_key             = data.terraform_remote_state.client.outputs.kubernetes_admin.private_key_pem
  cluster_ca_certificate = data.terraform_remote_state.client.outputs.kubernetes_admin.ca_cert_pem
}