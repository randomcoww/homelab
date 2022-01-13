output "ca" {
  value = {
    etcd = {
      algorithm       = tls_private_key.etcd-ca.algorithm
      private_key_pem = tls_private_key.etcd-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem
    }
    kubernetes = {
      algorithm       = tls_private_key.kubernetes-ca.algorithm
      private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
    }
  }
}

output "certs" {
  value = local.certs
}

output "encryption_config_secret" {
  value = base64encode(chomp(random_string.encryption-config-secret.result))
}

output "aws_s3_backup_credentials" {
  value = {
    access_key_id     = aws_iam_access_key.etcd-s3-backup.id
    access_key_secret = aws_iam_access_key.etcd-s3-backup.secret
  }
}