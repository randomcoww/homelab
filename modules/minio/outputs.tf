output "ignition_snippets" {
  value = local.module_ignition_snippets
}

output "minio_credentials" {
  value = {
    access_key_id     = random_password.minio-user.result
    secret_access_key = random_password.minio-password.result
  }
}