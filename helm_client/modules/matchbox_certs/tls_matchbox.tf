resource "tls_private_key" "matchbox" {
  algorithm   = tls_private_key.matchbox-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox" {
  private_key_pem = tls_private_key.matchbox.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  dns_names = [
  ]

  ip_addresses = [
    "127.0.0.1",
    var.api_listen_ip
  ]
}

resource "tls_locally_signed_cert" "matchbox" {
  cert_request_pem   = tls_cert_request.matchbox.cert_request_pem
  ca_private_key_pem = tls_private_key.matchbox-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}