##
## matchbox
##
resource "tls_cert_request" "matchbox" {
  key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
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

resource "tls_locally_signed_cert" "matchbox" {
  cert_request_pem   = "${tls_cert_request.matchbox.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.kubernetes.algorithm}"
  ca_private_key_pem = "${tls_private_key.kubernetes.private_key_pem}"
  ca_cert_pem        = "${tls_private_key.kubernetes.cert_pem}"
}
