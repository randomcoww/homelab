# KVM host access
output "kvm_passwords" {
  value = module.kickstart.kvm_passwords
}

# Minio UI access
output "minio-auth" {
  value = {
    access_key_id     = random_password.minio-user.result
    secret_access_key = random_password.minio-password.result
  }
}