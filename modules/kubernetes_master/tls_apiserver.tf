resource "tls_private_key" "apiserver" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "apiserver" {
  key_algorithm   = tls_private_key.apiserver.algorithm
  private_key_pem = tls_private_key.apiserver.private_key_pem

  subject {
    common_name  = "kubernetes"
    organization = "kubernetes"
  }

  dns_names = [
    "kubernetes.default",
  ]

  ip_addresses = compact([
    "127.0.0.1",
    var.template_params.apiserver_vip,
    var.template_params.service_network.vips.apiserver,
  ])
}

resource "tls_locally_signed_cert" "apiserver" {
  cert_request_pem   = tls_cert_request.apiserver.cert_request_pem
  ca_key_algorithm   = var.ca.algorithm
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