resource "tls_private_key" "kubelet-client" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubelet-client" {
  private_key_pem = tls_private_key.kubelet-client.private_key_pem

  subject {
    common_name = var.kubelet_access_user
  }
}

resource "tls_locally_signed_cert" "kubelet-client" {
  cert_request_pem   = tls_cert_request.kubelet-client.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}