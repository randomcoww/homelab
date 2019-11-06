output "cluster_name" {
  value = var.cluster_name
}

output "apiserver_endpoint" {
  value = "https://${var.services.kubernetes_apiserver.vip}:${var.services.kubernetes_apiserver.ports.secure}"
}

output "kubernetes_cert_pem" {
  value = tls_locally_signed_cert.kubernetes-client.cert_pem
}

output "kubernetes_private_key_pem" {
  value = tls_private_key.kubernetes-client.private_key_pem
}

output "kubernetes_ca_pem" {
  value = tls_self_signed_cert.kubernetes-ca.cert_pem
}

output "kubernetes_cert_pem_base64" {
  value = replace(base64encode(chomp(tls_locally_signed_cert.kubernetes-client.cert_pem)), "\n", "")
}

output "kubernetes_private_key_pem_base64" {
  value = replace(base64encode(chomp(tls_private_key.kubernetes-client.private_key_pem)), "\n", "")
}

output "kubernetes_ca_pem_base64" {
  value = replace(base64encode(chomp(tls_self_signed_cert.kubernetes-ca.cert_pem)), "\n", "")
}