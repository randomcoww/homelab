# client #
resource "tls_private_key" "etcd-client" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd-client" {
  private_key_pem = tls_private_key.etcd-client.private_key_pem

  subject {
    common_name = "wrapper-etcd-client"
  }
}

resource "tls_locally_signed_cert" "etcd-client" {
  cert_request_pem   = tls_cert_request.etcd-client.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}