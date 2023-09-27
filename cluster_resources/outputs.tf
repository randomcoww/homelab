output "s3" {
  value = {
    for name, res in local.s3_resources :
    name => {
      resource          = res.resource
      access_key_id     = aws_iam_access_key.s3[name].id
      secret_access_key = aws_iam_access_key.s3[name].secret
      aws_region        = local.aws_region
    }
  }
  sensitive = true
}

output "cloudflare_dns_api_token" {
  value     = cloudflare_api_token.dns_edit.value
  sensitive = true
}

# etcd

output "etcd_ca" {
  value = {
    algorithm       = tls_private_key.etcd-ca.algorithm
    private_key_pem = tls_private_key.etcd-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem
  }
  sensitive = true
}

output "etcd_peer_ca" {
  value = {
    algorithm       = tls_private_key.etcd-peer-ca.algorithm
    private_key_pem = tls_private_key.etcd-peer-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.etcd-peer-ca.cert_pem
  }
  sensitive = true
}

# kubernetes

output "kubernetes_ca" {
  value = {
    algorithm       = tls_private_key.kubernetes-ca.algorithm
    private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
  }
  sensitive = true
}

output "kubernetes_service_account" {
  value = {
    algorithm       = tls_private_key.service-account.algorithm
    public_key_pem  = tls_private_key.service-account.public_key_pem
    private_key_pem = tls_private_key.service-account.private_key_pem
  }
  sensitive = true
}

##

output "ssh_ca" {
  value = {
    algorithm          = tls_private_key.ssh-ca.algorithm
    private_key_pem    = tls_private_key.ssh-ca.private_key_pem
    public_key_openssh = tls_private_key.ssh-ca.public_key_openssh
  }
  sensitive = true
}

output "matchbox_ca" {
  value = {
    algorithm       = tls_private_key.matchbox-ca.algorithm
    private_key_pem = tls_private_key.matchbox-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem
  }
  sensitive = true
}

output "authelia" {
  value = {
    storage_secret = random_password.authelia-storage-secret.result
  }
  sensitive = true
}

output "letsencrypt" {
  value = {
    private_key_pem         = tls_private_key.letsencrypt-prod.private_key_pem
    staging_private_key_pem = tls_private_key.letsencrypt-staging.private_key_pem
  }
  sensitive = true
}

output "minio" {
  value = {
    access_key_id     = random_password.minio-access-key-id.result
    secret_access_key = random_password.minio-secret-access-key.result
  }
  sensitive = true
}