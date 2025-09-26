resource "tls_private_key" "kube-etcd" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kube-etcd" {
  private_key_pem = tls_private_key.kube-etcd.private_key_pem

  subject {
    common_name = "kube-etcd"
  }

  ip_addresses = [
    "127.0.0.1",
    var.node_ip,
  ]
}

resource "tls_locally_signed_cert" "kube-etcd" {
  cert_request_pem   = tls_cert_request.kube-etcd.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}