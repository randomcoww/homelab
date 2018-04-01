## ca - key not distributed
resource "tls_private_key" "root" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "root" {
  key_algorithm   = "${tls_private_key.root.algorithm}"
  private_key_pem = "${tls_private_key.root.private_key_pem}"

  validity_period_hours = 43800
  # early_renewal_hours   = 8760
  is_ca_certificate = true
  allowed_uses = ["cert_signing"]
  subject {
    common_name = "internal"
  }
}


## ssh ca key
resource "tls_private_key" "ssh" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}
