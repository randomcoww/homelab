resource "tls_private_key" "lldap" {
  algorithm   = var.lldap_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = "4096"
}

resource "tls_cert_request" "lldap" {
  private_key_pem = tls_private_key.lldap.private_key_pem

  subject {
    common_name = "lldap"
  }
}

resource "tls_locally_signed_cert" "lldap" {
  cert_request_pem   = tls_cert_request.lldap.cert_request_pem
  ca_private_key_pem = var.lldap_ca.private_key_pem
  ca_cert_pem        = var.lldap_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}