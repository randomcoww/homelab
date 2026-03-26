resource "tls_private_key" "internal-client" {
  algorithm   = var.internal_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "internal-client" {
  private_key_pem = tls_private_key.internal-client.private_key_pem

  subject {
    common_name = var.name
  }
}

resource "tls_locally_signed_cert" "internal-client" {
  cert_request_pem   = tls_cert_request.internal-client.cert_request_pem
  ca_private_key_pem = var.internal_ca.private_key_pem
  ca_cert_pem        = var.internal_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "tls" {
  source  = "../../../modules/secret"
  name    = "${var.name}-tls"
  app     = var.name
  release = var.release
  data = {
    "tls.crt"      = tls_locally_signed_cert.internal-client.cert_pem
    "tls.key"      = tls_private_key.internal-client.private_key_pem
    "ca.crt"       = var.internal_ca.cert_pem
    RENOVATE_TOKEN = var.github_credentials.token # GITHUB_TOKEN cannot provide all permissions needed for renovate
  }
}