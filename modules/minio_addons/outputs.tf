output "manifests" {
  value = local.addon_manifests
}

output "endpoint" {
  value = {
    version = "10"
    aliases = {
      "${var.resource_name}" = {
        url       = "http://${var.minio_ip}:${var.minio_port}"
        accessKey = nonsensitive(random_password.minio-access-key-id.result)
        secretKey = nonsensitive(random_password.minio-secret-access-key.result)
        api       = "S3v4"
        path      = "auto"
      }
    }
  }
}