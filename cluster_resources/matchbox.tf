resource "tls_private_key" "matchbox-ca" {
  ## needs compatibility with iPXE
  # algorithm   = "ECDSA"
  # ecdsa_curve = "P521"
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "matchbox-ca" {
  private_key_pem = tls_private_key.matchbox-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "matchbox"
  }

  allowed_uses = [
    "digital_signature",
    "code_signing",
    "cert_signing",
    "crl_signing",
    "server_auth",
    "client_auth",
  ]
}