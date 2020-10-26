resource "tls_private_key" "libvirt-client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "libvirt-client" {
  key_algorithm   = tls_private_key.libvirt-client.algorithm
  private_key_pem = tls_private_key.libvirt-client.private_key_pem

  subject {
    common_name = "libvirt"
  }
}

resource "tls_locally_signed_cert" "libvirt-client" {
  cert_request_pem   = tls_cert_request.libvirt-client.cert_request_pem
  ca_key_algorithm   = tls_private_key.libvirt-ca.algorithm
  ca_private_key_pem = tls_private_key.libvirt-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.libvirt-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}