resource "tls_private_key" "kea-stork-agent" {
  algorithm   = tls_private_key.kea-ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "kea-stork-agent" {
  private_key_pem = tls_private_key.kea-stork-agent.private_key_pem_pkcs8

  subject {
    common_name = "kea-stork-agent"
  }
}

resource "tls_locally_signed_cert" "kea-stork-agent" {
  cert_request_pem   = tls_cert_request.kea-stork-agent.cert_request_pem
  ca_private_key_pem = tls_private_key.kea-ca.private_key_pem_pkcs8
  ca_cert_pem        = tls_self_signed_cert.kea-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}