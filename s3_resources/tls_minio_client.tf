resource "tls_private_key" "minio-client" {
  algorithm   = data.terraform_remote_state.host.outputs.internal_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "minio-client" {
  private_key_pem = tls_private_key.minio-client.private_key_pem

  subject {
    common_name = local.endpoints.fluxcd.name
  }
}

resource "tls_locally_signed_cert" "minio-client" {
  cert_request_pem   = tls_cert_request.minio-client.cert_request_pem
  ca_private_key_pem = data.terraform_remote_state.host.outputs.internal_ca.private_key_pem
  ca_cert_pem        = data.terraform_remote_state.host.outputs.internal_ca.cert_pem

  validity_period_hours = 8760
  early_renewal_hours   = 2160

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "minio-tls" {
  source    = "../modules/secret"
  name      = "${local.endpoints.fluxcd.name}-minio-client-tls"
  namespace = local.endpoints.fluxcd.namespace
  app       = local.endpoints.fluxcd.name
  release   = "0.1.0"
  data = {
    "tls.crt" = tls_locally_signed_cert.minio-client.cert_pem
    "tls.key" = tls_private_key.minio-client.private_key_pem
    "ca.crt"  = data.terraform_remote_state.host.outputs.internal_ca.cert_pem
  }
}