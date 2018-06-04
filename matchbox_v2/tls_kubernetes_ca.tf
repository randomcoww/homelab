##
## kubernetes ca
##
resource "tls_private_key" "kubernetes" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "kubernetes" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  validity_period_hours = 8760
  is_ca_certificate = true

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
