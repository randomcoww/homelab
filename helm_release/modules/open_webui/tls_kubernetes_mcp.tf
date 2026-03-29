resource "tls_private_key" "kubernetes-mcp" {
  algorithm   = var.internal_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "kubernetes-mcp" {
  private_key_pem = tls_private_key.kubernetes-mcp.private_key_pem

  subject {
    common_name = "${var.name}-kubernetes-mcp"
  }
  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "tls_locally_signed_cert" "kubernetes-mcp" {
  cert_request_pem   = tls_cert_request.kubernetes-mcp.cert_request_pem
  ca_private_key_pem = var.internal_ca.private_key_pem
  ca_cert_pem        = var.internal_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

module "tls-kubernetes-mcp" {
  source  = "../../../modules/secret"
  name    = "${var.name}-kubernetes-mcp-tls"
  app     = var.name
  release = var.release
  data = {
    "tls.crt" = tls_locally_signed_cert.kubernetes-mcp.cert_pem
    "tls.key" = tls_private_key.kubernetes-mcp.private_key_pem
    "ca.crt"  = var.internal_ca.cert_pem
  }
}