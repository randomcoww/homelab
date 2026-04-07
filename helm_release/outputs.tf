# minio

output "minio" {
  value = {
    endpoint          = "${local.services.minio.ip}:${local.service_ports.minio}"
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