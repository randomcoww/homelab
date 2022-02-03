output "ca" {
  value = {
    kubernetes = {
      algorithm       = tls_private_key.kubernetes-ca.algorithm
      private_key_pem = tls_private_key.kubernetes-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.kubernetes-ca.cert_pem
    }
  }
}

output "certs" {
  value = local.certs
}

output "encryption_config_secret" {
  value = base64encode(chomp(random_string.encryption-config-secret.result))
}