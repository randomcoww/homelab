##
## matchbox
##
resource "tls_private_key" "instance" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "instance" {
  key_algorithm   = "${tls_private_key.instance.algorithm}"
  private_key_pem = "${tls_private_key.instance.private_key_pem}"

  subject {
    common_name  = "system:node:${var.node_name}"
    organization = "system:nodes"
  }
}

resource "tls_locally_signed_cert" "instance" {
  cert_request_pem   = "${tls_cert_request.instance.cert_request_pem}"
  ca_key_algorithm   = "${var.ca_key_algorithm}"
  ca_private_key_pem = "${var.ca_private_key_pem}"
  ca_cert_pem        = "${var.ca_cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
