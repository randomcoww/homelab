resource "tls_private_key" "matchbox" {
  algorithm   = var.ca.matchbox.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox" {
  key_algorithm   = tls_private_key.matchbox.algorithm
  private_key_pem = tls_private_key.matchbox.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  dns_names = [
    var.hostname,
  ]

  ip_addresses = concat(["127.0.0.1"], flatten([
    for interface in values(local.interfaces) :
    [
      for tap in values(interface.taps) :
      tap.ip
    ]
  ]))
}

resource "tls_locally_signed_cert" "matchbox" {
  cert_request_pem   = tls_cert_request.matchbox.cert_request_pem
  ca_key_algorithm   = var.ca.matchbox.algorithm
  ca_private_key_pem = var.ca.matchbox.private_key_pem
  ca_cert_pem        = var.ca.matchbox.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}