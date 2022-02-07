resource "tls_private_key" "addons-manager" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "addons-manager" {
  key_algorithm   = tls_private_key.addons-manager.algorithm
  private_key_pem = tls_private_key.addons-manager.private_key_pem

  subject {
    common_name  = "kube-addons-manager"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "addons-manager" {
  cert_request_pem   = tls_cert_request.addons-manager.cert_request_pem
  ca_key_algorithm   = var.ca.algorithm
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}