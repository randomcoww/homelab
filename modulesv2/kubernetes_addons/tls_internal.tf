resource "tls_private_key" "internal" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "internal" {
  key_algorithm   = tls_private_key.internal.algorithm
  private_key_pem = tls_private_key.internal.private_key_pem

  subject {
    common_name  = var.domains.internal
    organization = var.domains.internal
  }

  dns_names = [
    "*.${var.domains.internal}",
  ]
}

resource "tls_locally_signed_cert" "internal" {
  cert_request_pem   = tls_cert_request.internal.cert_request_pem
  ca_key_algorithm   = tls_private_key.internal-ca.algorithm
  ca_private_key_pem = tls_private_key.internal-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.internal-ca.cert_pem

  validity_period_hours = 8760
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
