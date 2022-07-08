resource "tls_private_key" "etcd-peer-ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_self_signed_cert" "etcd-peer-ca" {
  key_algorithm   = tls_private_key.etcd-peer-ca.algorithm
  private_key_pem = tls_private_key.etcd-peer-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "etcd"
    organization = "etcd"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}