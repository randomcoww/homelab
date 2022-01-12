# server #
resource "tls_private_key" "etcd" {
  algorithm   = var.etcd_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd" {
  key_algorithm   = tls_private_key.etcd.algorithm
  private_key_pem = tls_private_key.etcd.private_key_pem

  subject {
    common_name  = each.value.hostname
    organization = "etcd"
  }

  dns_names = [
    each.value.hostname,
  ]

  ip_addresses = [
    "127.0.0.1",
    cidrhost(interface.prefix, var.host_netnum),
  ]
}

resource "tls_locally_signed_cert" "etcd" {
  cert_request_pem   = tls_cert_request.etcd.cert_request_pem
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

# client #
resource "tls_private_key" "etcd-client" {
  algorithm   = var.etcd_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd-client" {
  key_algorithm   = tls_private_key.etcd-client.algorithm
  private_key_pem = tls_private_key.etcd-client.private_key_pem

  subject {
    common_name  = each.value.hostname
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