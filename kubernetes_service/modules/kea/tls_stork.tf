resource "tls_private_key" "stork" {
  algorithm   = tls_private_key.stork-ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "stork" {
  private_key_pem = tls_private_key.stork.private_key_pem

  subject {
    common_name = var.name
  }
}

resource "tls_locally_signed_cert" "stork" {
  cert_request_pem   = tls_cert_request.stork.cert_request_pem
  ca_private_key_pem = tls_private_key.stork-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.stork-ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "stork-tls" {
  source  = "../../../modules/secret"
  name    = "${var.name}-stork-tls"
  app     = var.name
  release = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.stork.cert_pem
    "tls.key" = tls_private_key.stork.private_key_pem_pkcs8 # required format
    "ca.crt"  = tls_self_signed_cert.stork-ca.cert_pem
  }
}