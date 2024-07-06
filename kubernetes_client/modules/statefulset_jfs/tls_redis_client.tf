resource "tls_private_key" "redis-client" {
  algorithm   = var.jfs_redis_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = "4096"
}

resource "tls_cert_request" "redis-client" {
  private_key_pem = tls_private_key.redis-client.private_key_pem

  subject {
    common_name  = "keydb"
    organization = "keydb"
  }
}

resource "tls_locally_signed_cert" "redis-client" {
  cert_request_pem   = tls_cert_request.redis-client.cert_request_pem
  ca_private_key_pem = var.jfs_redis_ca.private_key_pem
  ca_cert_pem        = var.jfs_redis_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}