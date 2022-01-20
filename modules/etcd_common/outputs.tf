output "ca" {
  value = {
    etcd = {
      algorithm       = tls_private_key.etcd-ca.algorithm
      private_key_pem = tls_private_key.etcd-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.etcd-ca.cert_pem
    }
  }
}

output "certs" {
  value = local.certs
}

output "aws_user_access" {
  value = {
    id     = aws_iam_access_key.s3-backup.id
    secret = aws_iam_access_key.s3-backup.secret
  }
}

output "s3_backup_path" {
  value = local.s3_backup_path
}