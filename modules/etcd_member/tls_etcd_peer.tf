resource "tls_private_key" "etcd-peer" {
  algorithm   = var.peer_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd-peer" {
  key_algorithm   = tls_private_key.etcd-peer.algorithm
  private_key_pem = tls_private_key.etcd-peer.private_key_pem

  subject {
    common_name  = var.template_params.hostname
    organization = "etcd"
  }

  dns_names = [
    var.template_params.hostname,
  ]

  ip_addresses = [
    var.template_params.ip,
  ]
}

resource "tls_locally_signed_cert" "etcd-peer" {
  cert_request_pem   = tls_cert_request.etcd-peer.cert_request_pem
  ca_key_algorithm   = var.peer_ca.algorithm
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