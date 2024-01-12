# only supports RSA 2048
resource "tls_private_key" "sunshine-ca" {
  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "tls_self_signed_cert" "sunshine-ca" {
  private_key_pem = tls_private_key.sunshine-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "Sunshine Gamestream Host"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}
