resource "tls_private_key" "crio-metrics" {
  algorithm   = var.kubernetes_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "crio-metrics" {
  private_key_pem = tls_private_key.crio-metrics.private_key_pem

  subject {
    common_name = "crio-metrics"
  }

  ip_addresses = [
    "127.0.0.1",
    cidrhost(var.node_prefix, var.host_netnum),
  ]
}

resource "tls_locally_signed_cert" "crio-metrics" {
  cert_request_pem   = tls_cert_request.crio-metrics.cert_request_pem
  ca_private_key_pem = var.kubernetes_ca.private_key_pem
  ca_cert_pem        = var.kubernetes_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}