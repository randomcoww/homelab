resource "tls_private_key" "letsencrypt-prod" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_private_key" "letsencrypt-staging" {
  algorithm = "RSA"
  rsa_bits  = 4096
}