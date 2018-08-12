##
## provisioner ca
##
resource "tls_private_key" "root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "root" {
  key_algorithm   = "${tls_private_key.root.algorithm}"
  private_key_pem = "${tls_private_key.root.private_key_pem}"

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "root"
    organization = "root"
  }

  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "server_auth",
    "client_auth",
  ]
}