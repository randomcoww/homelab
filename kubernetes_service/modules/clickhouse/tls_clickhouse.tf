resource "tls_private_key" "clickhouse" {
  for_each = toset(local.members)

  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "clickhouse" {
  for_each = toset(local.members)

  private_key_pem = tls_private_key.clickhouse[each.key].private_key_pem

  subject {
    common_name = each.key
  }

  dns_names = concat([
    var.name,
    "${var.name}.${var.namespace}",
    var.service_hostname,
    "${each.key}.${local.peer_name}.${var.namespace}",
  ])
  ip_addresses = compact([
    "127.0.0.1",
  ])
}

resource "tls_locally_signed_cert" "clickhouse" {
  for_each = toset(local.members)

  cert_request_pem   = tls_cert_request.clickhouse[each.key].cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}