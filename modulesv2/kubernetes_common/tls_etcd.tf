##
## etcd server
##
resource "tls_private_key" "etcd" {
  for_each = var.controller_hosts

  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "etcd" {
  for_each = var.controller_hosts

  key_algorithm   = tls_private_key.etcd[each.key].algorithm
  private_key_pem = tls_private_key.etcd[each.key].private_key_pem

  subject {
    common_name  = each.value.hostname
    organization = "etcd"
  }

  dns_names = [
    each.value.hostname,
  ]

  ip_addresses = compact([
    "127.0.0.1",
    lookup(each.value.host_network.main, "ip", null),
  ])
}

resource "tls_locally_signed_cert" "etcd" {
  for_each = var.controller_hosts

  cert_request_pem   = tls_cert_request.etcd[each.key].cert_request_pem
  ca_key_algorithm   = tls_private_key.etcd-ca.algorithm
  ca_private_key_pem = tls_private_key.etcd-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}