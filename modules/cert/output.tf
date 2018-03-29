output "cert_pem" {
  value       = "${tls_locally_signed_cert.instance.cert_pem}"
}

output "private_key_pem" {
  value       = "${tls_private_key.instance.private_key_pem}"
}
