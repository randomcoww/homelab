output "ignition_snippets" {
  value = local.module_ignition_snippets
}

output "credentials" {
  value = {
    hostname          = var.hostname
    access_key_id     = nonsensitive(random_password.minio-access-key-id.result)
    secret_access_key = nonsensitive(random_password.minio-secret-access-key.result)
  }
}