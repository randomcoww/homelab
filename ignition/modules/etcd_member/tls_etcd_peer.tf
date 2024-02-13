resource "tls_private_key" "kube-etcd-peer" {
  algorithm   = var.peer_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kube-etcd-peer" {
  private_key_pem = tls_private_key.kube-etcd-peer.private_key_pem

  subject {
    common_name = "kube-etcd-peer"
  }

  ip_addresses = concat(["127.0.0.1"], var.etcd_ips)
}

resource "tls_locally_signed_cert" "kube-etcd-peer" {
  cert_request_pem   = tls_cert_request.kube-etcd-peer.cert_request_pem
  ca_private_key_pem = var.peer_ca.private_key_pem
  ca_cert_pem        = var.peer_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}