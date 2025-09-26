provider "helm" {
  kubernetes = {
    host                   = "https://${local.services.apiserver.ip}:${local.host_ports.apiserver}"
    client_certificate     = data.terraform_remote_state.client.outputs.kubernetes_admin.cert_pem
    client_key             = data.terraform_remote_state.client.outputs.kubernetes_admin.private_key_pem
    cluster_ca_certificate = data.terraform_remote_state.client.outputs.kubernetes_admin.ca_cert_pem
  }
}

provider "minio" {
  minio_server   = "${local.services.minio.ip}:${local.service_ports.minio}"
  minio_user     = data.terraform_remote_state.sr.outputs.minio.access_key_id
  minio_password = data.terraform_remote_state.sr.outputs.minio.secret_access_key
  minio_ssl      = true
  # CA needs to be provided as a file which in inconvenient for an argument to a provider
  minio_insecure = true
  # minio_cert_file = "outputs/trusted-ca.crt"
}

provider "github" {
  token = var.github.arc_runners_token
}