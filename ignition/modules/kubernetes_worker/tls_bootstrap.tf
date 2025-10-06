resource "tls_private_key" "bootstrap" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "bootstrap" {
  private_key_pem = tls_private_key.bootstrap.private_key_pem

  subject {
    common_name  = var.kubelet_bootstrap_user
    organization = "system:bootstrappers"
  }
}

resource "tls_locally_signed_cert" "bootstrap" {
  cert_request_pem   = tls_cert_request.bootstrap.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}