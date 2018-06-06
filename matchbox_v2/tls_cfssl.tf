##
## matchbox
##
resource "tls_private_key" "cfssl" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "cfssl" {
  key_algorithm   = "${tls_private_key.cfssl.algorithm}"
  private_key_pem = "${tls_private_key.cfssl.private_key_pem}"

  subject {
    common_name  = "cfssl"
    organization = "cfssl"
  }

  dns_names = [
    "host.internal",
    "svc.internal"
  ]

  ip_addresses = [
    "127.0.0.1",
    "192.168.126.240"
  ]
}

resource "tls_locally_signed_cert" "cfssl" {
  cert_request_pem   = "${tls_cert_request.cfssl.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
