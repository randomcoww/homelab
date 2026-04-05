resource "tls_private_key" "store" {
  for_each = {
    for _, member in local.members :
    member.name => member
  }

  algorithm   = tls_private_key.store-ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "store" {
  for_each = {
    for _, member in local.members :
    member.name => member
  }

  private_key_pem = tls_private_key.store[each.key].private_key_pem
  subject {
    common_name = each.value.hostname
  }
  ip_addresses = [
    "127.0.0.1",
  ]
  dns_names = [
    each.value.hostname,
  ]
}

resource "tls_locally_signed_cert" "store" {
  for_each = {
    for _, member in local.members :
    member.name => member
  }

  cert_request_pem   = tls_cert_request.store[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.store-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.store-ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

module "store-tls" {
  source  = "../../../modules/secret"
  name    = "${var.name}-thanos-store-tls"
  app     = var.name
  release = "0.1.0"
  data = merge({
    for _, member in local.members :
    "${member.name}-tls.crt" => tls_locally_signed_cert.store[member.name].cert_pem
    }, {
    for _, member in local.members :
    "${member.name}-tls.key" => tls_private_key.store[member.name].private_key_pem
    }, {
    "ca.crt" = tls_self_signed_cert.store-ca.cert_pem
  })
}