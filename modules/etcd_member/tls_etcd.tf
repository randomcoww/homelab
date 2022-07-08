resource "tls_private_key" "etcd" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd" {
  key_algorithm   = tls_private_key.etcd.algorithm
  private_key_pem = tls_private_key.etcd.private_key_pem

  subject {
    common_name  = "etcd"
    organization = "etcd"
  }

  ip_addresses = [
    "127.0.0.1",
    var.member.client_ip,
  ]
}

resource "tls_locally_signed_cert" "etcd" {
  cert_request_pem   = tls_cert_request.etcd.cert_request_pem
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