provider "helm" {
  kubernetes = {
    host                   = "https://${local.vips.apiserver.ip}:${local.host_ports.apiserver}"
    client_certificate     = data.terraform_remote_state.host.outputs.kubernetes_client.cert_pem
    client_key             = data.terraform_remote_state.host.outputs.kubernetes_client.private_key_pem
    cluster_ca_certificate = data.terraform_remote_state.host.outputs.kubernetes_ca.cert_pem
  }
}

provider "minio" {
  minio_server   = "${local.endpoints.minio.service_ip}:${local.service_ports.minio}"
  minio_user     = data.terraform_remote_state.bootstrap.outputs.minio.access_key_id
  minio_password = data.terraform_remote_state.bootstrap.outputs.minio.secret_access_key
  minio_ssl      = true
  # CA needs to be provided as a file which in inconvenient for an argument to a provider
  minio_insecure = true
  # minio_cert_file = "outputs/internal-ca.crt"
}