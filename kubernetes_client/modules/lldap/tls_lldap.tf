resource "tls_private_key" "lldap" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "lldap" {
  private_key_pem = tls_private_key.lldap.private_key_pem

  subject {
    common_name  = "lldap"
    organization = "lldap"
  }

  dns_names = [
    var.service_hostname,
    "${var.name}.${var.namespace}",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "lldap" {
  cert_request_pem   = tls_cert_request.lldap.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}