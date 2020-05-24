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

# Add to ~/.ssh/known_hosts @cert-authority * <key>
output "ssh-ca-authorized-key" {
  value = module.ssh-common.ssh_ca_authorized_key
}

# Signed client public key for ~/.ssh/id_ecdsa-cert.pub
output "ssh-client-certificate" {
  value = module.ssh-common.ssh_client_certificate
}

# Module outputs are not automatically generated unless called in a resource
resource "null_resource" "output-triggers" {
  triggers = {
    ssh_ca_authorized_key = module.ssh-common.ssh_ca_authorized_key
    ssh_client_certificate = module.ssh-common.ssh_client_certificate
  }
}