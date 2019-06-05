output "matchbox_cert_pem" {
  value = "${tls_locally_signed_cert.client.cert_pem}"
}

output "matchbox_private_key_pem" {
  value = "${tls_private_key.client.private_key_pem}"
}

output "matchbox_ca_pem" {
  value = "${tls_self_signed_cert.matchbox_ca.cert_pem}"
}
