
resource "tls_private_key" "syncthing" {
  for_each = var.hosts

  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "syncthing" {
  for_each = var.hosts

  key_algorithm   = tls_private_key.syncthing[each.key].algorithm
  private_key_pem = tls_private_key.syncthing[each.key].private_key_pem

  subject {
    common_name = "syncthing"
  }
}

resource "tls_locally_signed_cert" "syncthing" {
  for_each = var.hosts

  cert_request_pem   = tls_cert_request.syncthing[each.key].cert_request_pem
  ca_key_algorithm   = tls_private_key.syncthing-ca.algorithm
  ca_private_key_pem = tls_private_key.syncthing-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.syncthing-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

data "syncthing" "syncthing" {
  for_each = var.hosts

  cert_pem        = tls_locally_signed_cert.syncthing[each.key].cert_pem
  private_key_pem = tls_private_key.syncthing[each.key].private_key_pem
}