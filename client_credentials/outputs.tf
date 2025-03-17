output "ssh_user_cert_authorized_key" {
  value = ssh_user_cert.ssh-client.cert_authorized_key
}

output "kubernetes_admin" {
  value = {
    algorithm       = tls_private_key.kubernetes-admin.algorithm
    private_key_pem = tls_private_key.kubernetes-admin.private_key_pem
    cert_pem        = tls_locally_signed_cert.kubernetes-admin.cert_pem
    ca_cert_pem     = data.terraform_remote_state.sr.outputs.kubernetes.ca.cert_pem
  }
  sensitive = true
}

output "matchbox_client" {
  value = {
    algorithm       = tls_private_key.matchbox-client.algorithm
    private_key_pem = tls_private_key.matchbox-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.matchbox-client.cert_pem
    ca_cert_pem     = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  }
  sensitive = true
}

output "minio_client" {
  value = {
    algorithm       = tls_private_key.minio-client.algorithm
    private_key_pem = tls_private_key.minio-client.private_key_pem
    cert_pem        = tls_locally_signed_cert.minio-client.cert_pem
    ca_cert_pem     = data.terraform_remote_state.sr.outputs.trust.ca.cert_pem
  }
  sensitive = true
}

output "kubeconfig" {
  value     = module.admin-kubeconfig.manifest
  sensitive = true
}

output "kubeconfig_cluster" {
  value     = module.admin-kubeconfig-cluster.manifest
  sensitive = true
}

output "mc_config" {
  value = {
    version = "10"
    aliases = merge({
      m = {
        url       = "https://${local.services.minio.ip}:${local.service_ports.minio}"
        accessKey = data.terraform_remote_state.sr.outputs.minio.access_key_id
        secretKey = data.terraform_remote_state.sr.outputs.minio.secret_access_key
        api       = "S3v4"
        path      = "auto"
      }
      }, {
      for name, res in data.terraform_remote_state.sr.outputs.r2_bucket :
      "cf-${name}" => {
        url       = "https://${res.url}"
        accessKey = res.access_key_id
        secretKey = res.secret_access_key
        api       = "S3v4"
        path      = "auto"
      }
    })
  }
  sensitive = true
}