resource "tls_private_key" "cockroachdb" {
  for_each = toset(local.members)

  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = "4096"
}

resource "tls_cert_request" "cockroachdb" {
  for_each = toset(local.members)

  private_key_pem = tls_private_key.cockroachdb[each.key].private_key_pem

  subject {
    common_name = "node"
  }

  dns_names = concat([
    "localhost",
    "${each.key}.${var.cluster_service_endpoint}",
    ], [
    for i, _ in split(".", var.cluster_service_endpoint) :
    join(".", slice(split(".", var.cluster_service_endpoint), 0, i + 1))
  ])
  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "cockroachdb" {
  for_each = toset(local.members)

  cert_request_pem   = tls_cert_request.cockroachdb[each.key].cert_request_pem
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