resource "tls_private_key" "store-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "store-ca" {
  private_key_pem = tls_private_key.store-ca.private_key_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160
  is_ca_certificate     = true

  subject {
    common_name = "${var.name}-store"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}
