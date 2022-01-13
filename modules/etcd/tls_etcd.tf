resource "tls_private_key" "etcd-server" {
  algorithm   = var.etcd_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd-server" {
  key_algorithm   = tls_private_key.etcd-server.algorithm
  private_key_pem = tls_private_key.etcd-server.private_key_pem

  subject {
    common_name  = var.hostname
    organization = "etcd"
  }

  dns_names = [
    var.hostname,
  ]

  ip_addresses = [
    "127.0.0.1",
    cidrhost(var.network_prefix, var.host_netnum),
  ]
}

resource "tls_locally_signed_cert" "etcd-server" {
  cert_request_pem   = tls_cert_request.etcd-server.cert_request_pem
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