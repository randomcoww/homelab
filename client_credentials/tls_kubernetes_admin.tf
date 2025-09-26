# admin client

resource "tls_private_key" "kubernetes-admin" {
  algorithm   = data.terraform_remote_state.sr.outputs.kubernetes.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubernetes-admin" {
  private_key_pem = tls_private_key.kubernetes-admin.private_key_pem

  subject {
    common_name  = "kubernetes-super-admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "kubernetes-admin" {
  cert_request_pem   = tls_cert_request.kubernetes-admin.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.sr.outputs.kubernetes.ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "admin-kubeconfig" {
  source             = "../modules/kubeconfig"
  cluster_name       = local.kubernetes.cluster_name
  user               = "kubernetes-super-admin"
  apiserver_endpoint = "https://${local.services.apiserver.ip}:${local.host_ports.apiserver}"
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.kubernetes-admin.cert_pem
  client_key_pem     = tls_private_key.kubernetes-admin.private_key_pem
}

# with apiserver cluster IP endpoint
module "admin-kubeconfig-cluster" {
  source             = "../modules/kubeconfig"
  cluster_name       = local.kubernetes.cluster_name
  user               = "kubernetes-super-admin"
  apiserver_endpoint = "https://${local.services.cluster_apiserver.ip}:443"
  ca_cert_pem        = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem
  client_cert_pem    = tls_locally_signed_cert.kubernetes-admin.cert_pem
  client_key_pem     = tls_private_key.kubernetes-admin.private_key_pem
}