resource "tls_private_key" "trusted-ca" {
  ## needs compatibility with iPXE
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "trusted-ca" {
  private_key_pem = tls_private_key.trusted-ca.private_key_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160
  is_ca_certificate     = true

  subject {
    common_name = local.domains.public
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "code_signing",
    "cert_signing",
    "crl_signing",
    "server_auth",
    "client_auth",
  ]
}