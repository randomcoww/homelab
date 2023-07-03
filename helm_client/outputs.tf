output "mc_config" {
  value = {
    version = "10"
    aliases = {
      m = {
        url       = "http://${local.kubernetes_ingress_endpoints.minio}:${local.ports.minio}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
      s3 = {
        url       = "https://s3.amazonaws.com"
        accessKey = aws_iam_access_key.s3-backup.id
        secretKey = nonsensitive(aws_iam_access_key.s3-backup.secret)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
}
