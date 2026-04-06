# minio

output "minio" {
  value = {
    access_key_id     = random_password.minio-access-key-id.result
    secret_access_key = random_password.minio-secret-access-key.result
  }
  sensitive = true
}

# lldap admin

output "lldap" {
  value = {
    dn   = random_password.lldap-user.result
    pass = random_password.lldap-password.result
  }
  sensitive = true
}

# llama.cpp auth token

output "llama-cpp" {
  value = {
    api_key = random_password.llama-cpp-auth-token.result
  }
  sensitive = true
}

# storage access from MC and rclone

output "mc_config" {
  value = jsonencode({
    version = "10"
    aliases = {
      m = {
        url       = "https://${local.services.minio.ip}:${local.service_ports.minio}"
        accessKey = random_password.minio-access-key-id.result
        secretKey = random_password.minio-secret-access-key.result
        api       = "S3v4"
        path      = "auto"
      }
    }
  })
  sensitive = true
}

output "rclone_config" {
  value     = <<EOF
[m]
type = s3
provider = Minio
access_key_id = ${random_password.minio-access-key-id.result}
secret_access_key = ${random_password.minio-secret-access-key.result}
region = auto
endpoint = https://${local.services.minio.ip}:${local.service_ports.minio}
EOF
  sensitive = true
}