resource "random_password" "lldap-storage-secret" {
  length  = 128
  special = false
}

resource "random_password" "lldap-jwt-token" {
  length  = 128
  special = true
}

resource "random_password" "lldap-user" {
  length  = 64
  special = false
}

resource "random_password" "lldap-password" {
  length  = 64
  special = false
}

resource "tls_private_key" "lldap-ca" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "tls_self_signed_cert" "lldap-ca" {
  private_key_pem = tls_private_key.lldap-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name  = "lldap"
    organization = "lldap"
  }

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "cert_signing",
    "server_auth",
    "client_auth",
  ]
}