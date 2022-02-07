# matchbox client #
resource "tls_private_key" "matchbox-client" {
  algorithm   = module.addons-pxeboot.ca.matchbox.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox-client" {
  key_algorithm   = tls_private_key.matchbox-client.algorithm
  private_key_pem = tls_private_key.matchbox-client.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }

  ip_addresses = [
    "192.168.126.130",
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "matchbox-client" {
  cert_request_pem   = tls_cert_request.matchbox-client.cert_request_pem
  ca_key_algorithm   = module.addons-pxeboot.ca.matchbox.algorithm
  ca_private_key_pem = module.addons-pxeboot.ca.matchbox.private_key_pem
  ca_cert_pem        = module.addons-pxeboot.ca.matchbox.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
