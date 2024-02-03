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

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}