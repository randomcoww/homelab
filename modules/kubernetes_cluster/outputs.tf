output "kubernetes_cert_pem" {
  value = "${tls_locally_signed_cert.admin.cert_pem}"
}

output "kubernetes_private_key_pem" {
  value = "${tls_private_key.admin.private_key_pem}"
}

output "kubernetes_ca_pem" {
  value = "${tls_self_signed_cert.root.cert_pem}"
}
