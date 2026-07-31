resource "tls_private_key" "letsencrypt-prod" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "letsencrypt-staging" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "letsencrypt" {
  value = {
    private_key_pem = tls_private_key.letsencrypt-prod.private_key_pem
    username        = var.letsencrypt_username
  }
  sensitive = true
}