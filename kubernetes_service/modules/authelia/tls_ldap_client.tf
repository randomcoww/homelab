resource "tls_private_key" "ldap-client" {
  algorithm   = var.ldap_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "ldap-client" {
  private_key_pem = tls_private_key.ldap-client.private_key_pem

  subject {
    common_name = var.name
  }
}

resource "tls_locally_signed_cert" "ldap-client" {
  cert_request_pem   = tls_cert_request.ldap-client.cert_request_pem
  ca_private_key_pem = var.ldap_ca.private_key_pem
  ca_cert_pem        = var.ldap_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "ldap-tls" {
  source  = "../../../modules/secret"
  name    = "${var.name}-ldap-tls"
  app     = var.name
  release = var.release
  data = {
    "tls.crt" = tls_locally_signed_cert.ldap-client.cert_pem
    "tls.key" = tls_private_key.ldap-client.private_key_pem
    "ca.crt"  = var.ldap_ca.cert_pem
  }
}