# client #
resource "tls_private_key" "etcd-client" {
  algorithm   = var.etcd_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd-client" {
  key_algorithm   = tls_private_key.etcd-client.algorithm
  private_key_pem = tls_private_key.etcd-client.private_key_pem

  subject {
    common_name  = "etcd"
    organization = "etcd"
  }
}

resource "tls_locally_signed_cert" "etcd-client" {
  cert_request_pem   = tls_cert_request.etcd-client.cert_request_pem
  ca_key_algorithm   = var.etcd_ca.algorithm
  ca_private_key_pem = var.etcd_ca.private_key_pem
  ca_cert_pem        = var.etcd_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}