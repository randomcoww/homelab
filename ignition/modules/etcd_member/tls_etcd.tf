resource "tls_private_key" "etcd" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd" {
  private_key_pem = tls_private_key.etcd.private_key_pem

  subject {
    common_name = "kube-etcd"
  }

  ip_addresses = concat(["127.0.0.1"], var.etcd_ips)
}

resource "tls_locally_signed_cert" "etcd" {
  cert_request_pem   = tls_cert_request.etcd.cert_request_pem
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