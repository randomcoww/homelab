resource "tls_private_key" "kea" {
  for_each = {
    for _, member in local.members :
    member.name => member.ip
  }

  algorithm   = tls_private_key.kea-ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "kea" {
  for_each = {
    for _, member in local.members :
    member.name => member.ip
  }

  private_key_pem = tls_private_key.kea[each.key].private_key_pem
  subject {
    common_name = "kea-${each.key}"
  }

  dns_names = []
  ip_addresses = [
    # "127.0.0.1",
    # each.value,
  ]
}

resource "tls_locally_signed_cert" "kea" {
  for_each = {
    for _, member in local.members :
    member.name => member.ip
  }

  cert_request_pem   = tls_cert_request.kea[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.kea-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.kea-ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "server_auth",
  ]
}