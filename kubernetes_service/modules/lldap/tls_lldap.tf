resource "tls_private_key" "lldap" {
  algorithm   = var.ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "lldap" {
  private_key_pem = tls_private_key.lldap.private_key_pem

  subject {
    common_name = var.name
  }
  ip_addresses = [
    "127.0.0.1",
  ]
  dns_names = [
    var.service_hostname,
  ]
}

resource "tls_locally_signed_cert" "lldap" {
  cert_request_pem   = tls_cert_request.lldap.cert_request_pem
  ca_private_key_pem = var.ca.private_key_pem
  ca_cert_pem        = var.ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

module "tls" {
  source  = "../../../modules/secret"
  name    = "${var.name}-tls"
  app     = var.name
  release = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.lldap.cert_pem
    "tls.key" = tls_private_key.lldap.private_key_pem
    "ca.crt"  = var.ca.cert_pem
  }
}