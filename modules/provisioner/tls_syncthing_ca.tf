##
## syncthing ca
##
resource "tls_private_key" "syncthing_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "syncthing_ca" {
  key_algorithm   = "${tls_private_key.syncthing_ca.algorithm}"
  private_key_pem = "${tls_private_key.syncthing_ca.private_key_pem}"

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "syncthing"
    organization = "syncthing"
  }

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]
}
