resource "tls_private_key" "registry-client" {
  for_each = {
    for _, reg in var.internal_registries :
    "${reg.prefix}" => reg
  }

  algorithm   = var.registry_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "registry-client" {
  for_each = {
    for _, reg in var.internal_registries :
    "${reg.prefix}" => reg
  }

  private_key_pem = var.registry_ca.private_key_pem

  subject {
    common_name = each.key
  }
}

resource "tls_locally_signed_cert" "registry-client" {
  for_each = {
    for _, reg in var.internal_registries :
    "${reg.prefix}" => reg
  }

  cert_request_pem   = tls_cert_request.registry-client[each.key].cert_request_pem
  ca_private_key_pem = var.registry_ca.private_key_pem
  ca_cert_pem        = var.registry_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}