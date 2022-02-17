resource "tls_private_key" "matchbox-client" {
  algorithm   = tls_private_key.matchbox-ca.algorithm
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "matchbox-client" {
  key_algorithm   = tls_private_key.matchbox-client.algorithm
  private_key_pem = tls_private_key.matchbox-client.private_key_pem

  subject {
    common_name  = "matchbox"
    organization = "matchbox"
  }
}

resource "tls_locally_signed_cert" "matchbox-client" {
  cert_request_pem   = tls_cert_request.matchbox-client.cert_request_pem
  ca_key_algorithm   = tls_private_key.matchbox-ca.algorithm
  ca_private_key_pem = tls_private_key.matchbox-ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}

resource "local_file" "pxeboot_certs" {
  for_each = {
    "matchbox-ca.pem"   = tls_self_signed_cert.matchbox-ca.cert_pem
    "matchbox-cert.pem" = tls_locally_signed_cert.matchbox-client.cert_pem
    "matchbox-key.pem"  = tls_private_key.matchbox-client.private_key_pem
  }

  filename = "./output/certs/${each.key}"
  content  = each.value
}