output "ssh_user_cert_authorized_key" {
  value = ssh_user_cert.ssh-client.cert_authorized_key
}

output "zot_client" {
  value = {
    private_key_pem = tls_private_key.zot-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.zot-client.cert_pem
  }
  sensitive = true
}

output "kubeconfig" {
  value     = module.kubeconfig.manifest
  sensitive = true
}