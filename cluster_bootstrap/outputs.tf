# minio

output "minio" {
  value = {
    endpoint          = "${local.services.minio.ip}:${local.service_ports.minio}"
    access_key_id     = random_password.minio-access-key-id.result
    secret_access_key = random_password.minio-secret-access-key.result
  }
  sensitive = true
}