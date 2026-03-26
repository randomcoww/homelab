# provider credentials for other terraform modules #

# Terraform providers can only use things like vars or remote_state for input.
# Generate client certs here to use with kubernetes_services and minio_resources.

resource "tls_private_key" "kubernetes-client" {
  algorithm   = tls_private_key.kubernetes-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubernetes-client" {
  private_key_pem = tls_private_key.kubernetes-client.private_key_pem

  subject {
    common_name  = "kubernetes-super-admin"
    organization = "system:masters"
  }
}

resource "tls_locally_signed_cert" "kubernetes-client" {
  cert_request_pem   = tls_cert_request.kubernetes-client.cert_request_pem
  ca_private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}