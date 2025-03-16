resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

resource "tls_private_key" "minio-ca" {
  ## needs compatibility with iPXE
  # algorithm   = "ECDSA"
  # ecdsa_curve = "P521"
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "minio-ca" {
  private_key_pem = tls_private_key.minio-ca.private_key_pem

  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "minio"
  }

  allowed_uses = [
    "digital_signature",
    "code_signing",
    "cert_signing",
    "crl_signing",
    "server_auth",
    "client_auth",
  ]
}