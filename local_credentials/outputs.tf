output "ssh_user_cert_authorized_key" {
  value = ssh_user_cert.ssh-client.cert_authorized_key
}

output "registry_client" {
  value = {
    private_key_pem = tls_private_key.registry-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.registry-client.cert_pem
  }
  sensitive = true
}

output "kubernetes_client" {
  value = {
    algorithm       = tls_private_key.kubernetes-client.algorithm
    private_key_pem = tls_private_key.kubernetes-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.kubernetes-client.cert_pem
  }
  sensitive = true
}

output "kubeconfig" {
  value     = module.kubeconfig.manifest
  sensitive = true
}