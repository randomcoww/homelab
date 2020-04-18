# Minio UI access
output "minio-auth" {
  value = {
    access_key_id     = random_password.minio-user.result
    secret_access_key = random_password.minio-password.result
  }
}

# Grafana auth
output "grafana-auth" {
  value = {
    user     = random_password.grafana-user.result
    password = random_password.grafana-password.result
  }
}