output "alpaca-db" {
  value = {
    ca = {
      algorithm       = tls_private_key.alpaca-db-ca.algorithm
      private_key_pem = tls_private_key.alpaca-db-ca.private_key_pem
      cert_pem        = tls_self_signed_cert.alpaca-db-ca.cert_pem
    }
  }
  sensitive = true
}