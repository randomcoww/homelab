resource "tls_private_key" "kea-ctrl-agent" {
  algorithm   = tls_private_key.kea-ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "kea-ctrl-agent" {
  private_key_pem = tls_private_key.kea-ctrl-agent.private_key_pem

  subject {
    common_name = "kea-ctrl-agent"
  }

  dns_names = []
  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "kea-ctrl-agent" {
  cert_request_pem   = tls_cert_request.kea-ctrl-agent.cert_request_pem
  ca_private_key_pem = tls_private_key.kea-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.kea-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}