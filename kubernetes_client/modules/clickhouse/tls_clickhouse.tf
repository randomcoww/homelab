resource "tls_private_key" "clickhouse" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = "4096"
}

resource "tls_cert_request" "clickhouse" {
  private_key_pem = tls_private_key.clickhouse.private_key_pem

  subject {
    common_name  = var.name
    organization = var.name
  }

  dns_names = concat([
    for i, _ in split(".", var.cluster_service_endpoint) :
    join(".", slice(split(".", var.cluster_service_endpoint), 0, i + 1))
    ], [
    var.service_hostname,
  ])
  ip_addresses = [
    var.service_ip
  ]
}

resource "tls_locally_signed_cert" "clickhouse" {
  cert_request_pem   = tls_cert_request.clickhouse.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}