##
## matchbox
##
resource "tls_private_key" "matchbox" {
  for_each = var.kvm_hosts

  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox" {
  for_each = var.kvm_hosts

  key_algorithm   = tls_private_key.matchbox[each.key].algorithm
  private_key_pem = tls_private_key.matchbox[each.key].private_key_pem

  subject {
    common_name = "matchbox"
  }

  ip_addresses = [
    "127.0.0.1",
    each.value.network.store.ip
  ]
}

resource "tls_locally_signed_cert" "matchbox" {
  for_each = var.kvm_hosts

  cert_request_pem   = tls_cert_request.matchbox[each.key].cert_request_pem
  ca_key_algorithm   = tls_private_key.matchbox-ca.algorithm
  ca_private_key_pem = tls_private_key.matchbox-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
