##
## matchbox
##
resource "tls_private_key" "controller_manager" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "controller_manager" {
  key_algorithm   = "${tls_private_key.controller_manager.algorithm}"
  private_key_pem = "${tls_private_key.controller_manager.private_key_pem}"

  subject {
    common_name  = "system:kube-controller-manager"
    organization = "system:kube-controller-manager"
  }
}

resource "tls_locally_signed_cert" "controller_manager" {
  cert_request_pem   = "${tls_cert_request.controller_manager.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
