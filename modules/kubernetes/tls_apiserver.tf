resource "tls_private_key" "apiserver" {
  algorithm   = var.kubernetes_ca.algorithm
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
    var.hostname,
  ]

  ip_addresses = compact([
    "127.0.0.1",
    cidrhost(var.network_prefix, var.host_netnum),
    cidrhost(var.network_prefix, var.vip_netnum),
  ])
}

resource "tls_locally_signed_cert" "apiserver" {
  cert_request_pem   = tls_cert_request.apiserver.cert_request_pem
  ca_key_algorithm   = var.kubernetes_ca.algorithm
  ca_private_key_pem = var.kubernetes_ca.private_key_pem
  ca_cert_pem        = var.kubernetes_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}