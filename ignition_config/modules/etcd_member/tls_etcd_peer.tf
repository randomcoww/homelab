resource "tls_private_key" "etcd-peer" {
  algorithm   = var.peer_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd-peer" {
  private_key_pem = tls_private_key.etcd-peer.private_key_pem

  subject {
    common_name  = "etcd"
    organization = "etcd"
  }

  ip_addresses = [
    var.member.peer_ip,
  ]
}

resource "tls_locally_signed_cert" "etcd-peer" {
  cert_request_pem   = tls_cert_request.etcd-peer.cert_request_pem
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