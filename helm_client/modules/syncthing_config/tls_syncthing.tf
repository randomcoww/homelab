resource "tls_private_key" "syncthing" {
  count = var.replica_count

  algorithm   = tls_private_key.syncthing-ca.algorithm
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "syncthing" {
  count = var.replica_count

  private_key_pem = tls_private_key.syncthing[count.index].private_key_pem

  subject {
    common_name = "syncthing"
  }
}

resource "tls_locally_signed_cert" "syncthing" {
  count = var.replica_count

  cert_request_pem   = tls_cert_request.syncthing[count.index].cert_request_pem
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
  count = var.replica_count

  cert_pem        = tls_locally_signed_cert.syncthing[count.index].cert_pem
  private_key_pem = tls_private_key.syncthing[count.index].private_key_pem
}