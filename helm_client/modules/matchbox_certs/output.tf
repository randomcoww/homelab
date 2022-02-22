output "ca" {
  value = {
    algorithm       = tls_private_key.matchbox-ca.algorithm
    private_key_pem = tls_private_key.matchbox-ca.private_key_pem
    cert_pem        = tls_self_signed_cert.matchbox-ca.cert_pem
  }
}

output "secret" {
  value = {
    "ca.crt"     = replace(base64encode(chomp(tls_self_signed_cert.matchbox-ca.cert_pem)), "\n", "")
    "server.crt" = replace(base64encode(chomp(tls_locally_signed_cert.matchbox.cert_pem)), "\n", "")
    "server.key" = replace(base64encode(chomp(tls_private_key.matchbox.private_key_pem)), "\n", "")
  }
}

output "client" {
  value = {
    ca   = tls_self_signed_cert.matchbox-ca.cert_pem
    cert = tls_locally_signed_cert.matchbox-client.cert_pem
    key  = tls_private_key.matchbox-client.private_key_pem
  }
}