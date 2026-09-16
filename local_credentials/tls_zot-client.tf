resource "tls_private_key" "zot-client" {
  algorithm   = data.terraform_remote_state.host.outputs.internal_ca.algorithm
  ecdsa_curve = "P521"
  rsa_bits    = 4096
}

resource "tls_cert_request" "zot-client" {
  private_key_pem = tls_private_key.zot-client.private_key_pem

  subject {
    common_name = "worker"
  }
}

resource "tls_locally_signed_cert" "zot-client" {
  cert_request_pem   = tls_cert_request.zot-client.cert_request_pem
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