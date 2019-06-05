##
## local
##
resource "tls_private_key" "admin" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "admin" {
  key_algorithm   = "${tls_private_key.admin.algorithm}"
  private_key_pem = "${tls_private_key.admin.private_key_pem}"

  subject {
    common_name  = "admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = "${tls_cert_request.admin.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes_ca.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes_ca.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.kubernetes_ca.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
