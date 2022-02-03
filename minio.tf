resource "random_password" "minio-access-key-id" {
  length  = 30
  special = false
}

resource "random_password" "minio-secret-access-key" {
  length  = 30
  special = false
}

output "minio_credentials" {
  value = {
    access_key_id     = nonsensitive(random_password.minio-access-key-id.result)
    secret_access_key = nonsensitive(random_password.minio-secret-access-key.result)
  }
}