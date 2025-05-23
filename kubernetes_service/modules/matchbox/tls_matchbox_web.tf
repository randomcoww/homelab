resource "tls_private_key" "matchbox-web" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "matchbox-web" {
  private_key_pem = tls_private_key.matchbox-web.private_key_pem

  subject {
    common_name = "${var.name}-web"
  }

  dns_names = [
    var.name,
    "${var.name}.${var.namespace}",
  ]
  ip_addresses = [
    var.service_ip,
  ]
}

resource "tls_locally_signed_cert" "matchbox-web" {
  cert_request_pem   = tls_cert_request.matchbox-web.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}