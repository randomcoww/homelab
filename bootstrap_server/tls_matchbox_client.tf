resource "tls_private_key" "matchbox-client" {
  algorithm   = tls_private_key.matchbox-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox-client" {
  private_key_pem = tls_private_key.matchbox-client.private_key_pem

  subject {
    common_name = "matchbox"
  }
}

resource "tls_locally_signed_cert" "matchbox-client" {
  cert_request_pem   = tls_cert_request.matchbox-client.cert_request_pem
  ca_private_key_pem = tls_private_key.matchbox-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}