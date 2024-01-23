resource "tls_private_key" "syncthing" {
  for_each = toset(var.hostnames)

  algorithm   = tls_private_key.syncthing-ca.algorithm
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "syncthing" {
  for_each = toset(var.hostnames)

  private_key_pem = tls_private_key.syncthing[each.key].private_key_pem

  subject {
    common_name = "syncthing"
  }
}

resource "tls_locally_signed_cert" "syncthing" {
  for_each = toset(var.hostnames)

  cert_request_pem   = tls_cert_request.syncthing[each.key].cert_request_pem
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

data "syncthing_device" "syncthing" {
  for_each = toset(var.hostnames)

  cert_pem        = tls_locally_signed_cert.syncthing[each.key].cert_pem
  private_key_pem = tls_private_key.syncthing[each.key].private_key_pem
}