##
## internal CA for ingress
##
resource "tls_private_key" "internal-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "internal-ca" {
  key_algorithm         = tls_private_key.internal-ca.algorithm
  private_key_pem       = tls_private_key.internal-ca.private_key_pem
  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = var.domains.internal
    organization = var.domains.internal
  }

  allowed_uses = [
    "cert_signing",
  ]
}