resource "tls_private_key" "front-proxy-client" {
  algorithm   = var.front_proxy_ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "front-proxy-client" {
  private_key_pem = tls_private_key.front-proxy-client.private_key_pem

  subject {
    common_name = var.front_proxy_client_user
  }
}

resource "tls_locally_signed_cert" "front-proxy-client" {
  cert_request_pem   = tls_cert_request.front-proxy-client.cert_request_pem
  ca_private_key_pem = var.front_proxy_ca.private_key_pem
  ca_cert_pem        = var.front_proxy_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}