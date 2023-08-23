output "cert_pem" {
  value     = tls_locally_signed_cert.admin.cert_pem
  sensitive = true
}

output "key_pem" {
  value     = tls_private_key.admin.private_key_pem
  sensitive = true
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}