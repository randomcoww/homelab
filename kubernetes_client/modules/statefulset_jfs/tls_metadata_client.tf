resource "tls_private_key" "metadata-client" {
  algorithm   = var.jfs_metadata_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = "4096"
}

resource "tls_cert_request" "metadata-client" {
  private_key_pem = tls_private_key.metadata-client.private_key_pem

  subject {
    common_name = var.tls_cn
  }
}

resource "tls_locally_signed_cert" "metadata-client" {
  cert_request_pem   = tls_cert_request.metadata-client.cert_request_pem
  ca_private_key_pem = var.jfs_metadata_ca.private_key_pem
  ca_cert_pem        = var.jfs_metadata_ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}