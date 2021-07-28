resource "tls_private_key" "ipxe" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "ipxe" {
  key_algorithm   = tls_private_key.ipxe.algorithm
  private_key_pem = tls_private_key.ipxe.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  dns_names = []

  ip_addresses = compact([
    "127.0.0.1",
    local.services.ipxe.vip,
  ])
}

resource "tls_locally_signed_cert" "ipxe" {
  cert_request_pem   = tls_cert_request.ipxe.cert_request_pem
  ca_key_algorithm   = tls_private_key.ipxe-ca.algorithm
  ca_private_key_pem = tls_private_key.ipxe-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ipxe-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
