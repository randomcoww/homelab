output "ssh_user_cert_authorized_key" {
  value = ssh_user_cert.ssh-client.cert_authorized_key
}

output "kubeconfig" {
  value = templatefile("./manifests/kubeconfig_admin.yaml", {
    cluster_name       = local.kubernetes.cluster_name
    apiserver_endpoint = local.services.apiserver.ip
    ca_cert_pem        = data.terraform_remote_state.sr.outputs.kubernetes_ca.cert_pem
    cert_pem           = tls_locally_signed_cert.kubernetes-admin.cert_pem
    private_key_pem    = tls_private_key.kubernetes-admin.private_key_pem
  })
  sensitive = true
}