locals {
  certs = {
    etcd = {
      ca_cert = {
        content = tls_self_signed_cert.etcd-ca.cert_pem
      }
      client_cert = {
        content = tls_locally_signed_cert.etcd-client.cert_pem
      }
      client_key = {
        content = tls_private_key.etcd-client.private_key_pem
      }
    }
  }

  s3_backup_path = "${var.s3_backup_bucket}/${var.s3_backup_key}"
}