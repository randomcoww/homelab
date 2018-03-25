output "cert_pem" {
  description = "CA"
  value       = "${tls_locally_signed_cert.instance.cert_pem}"
}

output "private_key_pem" {
  description = "Key"
  value       = "${tls_private_key.instance.private_key_pem}"
}
