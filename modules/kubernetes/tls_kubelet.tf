resource "tls_private_key" "kubelet" {
  algorithm   = var.kubernetes_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubelet" {
  key_algorithm   = tls_private_key.kubelet.algorithm
  private_key_pem = tls_private_key.kubelet.private_key_pem

  subject {
    common_name  = "system:node:${var.hostname}"
    organization = "system:node"
  }
}

resource "tls_locally_signed_cert" "kubelet" {
  cert_request_pem   = tls_cert_request.kubelet.cert_request_pem
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